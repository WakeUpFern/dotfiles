.pragma library

// Logica pura del launcher (sin QML): normalizacion, puntuacion difusa, calculadora, conversion de unidades
// y detalles de archivos. Se prueba con node (ver docs/launcher.md).

function norm(s) {
    s = (s || "").toLowerCase();
    try { return s.normalize("NFD").replace(/[̀-ͯ]/g, ""); } catch (e) { return s; }
}

// --- Busqueda difusa ---------------------------------------------------------------------------
// Subsecuencia con bonos al estilo fzf: limite de palabra, letras seguidas, coincidencia exacta y menos
// puntos por texto largo o por empezar tarde. Devuelve -1 si no coincide. `q` y `s` ya normalizados.
function fuzzy(q, s) {
    const ql = q.length;
    if (ql === 0) return 0;
    if (s.length < ql) return -1;
    const at = s.indexOf(q);
    if (at >= 0) {
        const boundary = at === 0 || " /_-.".indexOf(s.charAt(at - 1)) >= 0;
        return 60 + (boundary ? 20 : 0) - at * 0.4 - (s.length - ql) * 0.1;
    }
    let qi = 0, score = 0, last = -2, first = -1;
    for (let i = 0; i < s.length && qi < ql; i++) {
        if (s.charCodeAt(i) !== q.charCodeAt(qi)) continue;
        let b = 1;
        if (i === 0 || " /_-.".indexOf(s.charAt(i - 1)) >= 0) b += 6;
        if (last === i - 1) b += 4;
        score += b;
        last = i;
        if (first < 0) first = i;
        qi++;
    }
    if (qi < ql) return -1;
    return score - first * 0.3 - s.length * 0.05;
}

// Varias palabras ("informe 2024", "dotfiles launcher"): cada una debe coincidir, en el nombre (pesa mas) o en
// la ruta. `terms` ya normalizados; devuelve la suma o -1.
function fuzzyTerms(terms, base, rel) {
    let total = 0;
    for (let i = 0; i < terms.length; i++) {
        let s = fuzzy(terms[i], base);
        if (s >= 0) s += 10;
        else {
            s = pathScore(terms[i], rel);
            if (s < 0) return -1;
        }
        total += s;
    }
    return total;
}

// En la ruta (carpetas) las palabras se escriben completas: se exige coincidencia contigua, no letras sueltas
// (si no, "dotfiles" cuadraria con cualquier ruta larga).
function pathScore(t, rel) {
    const at = rel.indexOf(t);
    if (at < 0) return -1;
    return 8 + (at === 0 || rel.charAt(at - 1) === "/" ? 4 : 0);
}

// Tolerancia a erratas, solo como segunda pasada (cuando casi nada coincide) y estricta para no meter ruido:
// dos letras cambiadas de sitio ("shcema" -> "schema") o una letra de mas ("schhema"), buscadas como subcadena.
const TYPO_CACHE = {};
function typoVariants(t) {
    if (TYPO_CACHE[t]) return TYPO_CACHE[t];
    const out = [], seen = {};
    const add = v => { if (v !== t && !seen[v]) { seen[v] = true; out.push(v); } };
    for (let i = 0; i < t.length - 1; i++) add(t.slice(0, i) + t.charAt(i + 1) + t.charAt(i) + t.slice(i + 2));
    if (t.length >= 5) for (let i = 0; i < t.length; i++) add(t.slice(0, i) + t.slice(i + 1));
    TYPO_CACHE[t] = out;                                 // se pide por cada archivo: calcular una sola vez
    return out;
}
// Consulta de fzf que tolera erratas, en UNA sola pasada. Cada palabra normal de 4+ letras se vuelve
//   'cambiadas1 | 'cambiadas2 | ... | palabra | 'sinUnaLetra1 | ...
// (en fzf `|` es O, `'` es coincidencia exacta y las palabras separadas por espacio son Y). fzf usa la PRIMERA
// alternativa que coincide, asi que el orden importa:
//   1) letras cambiadas de sitio ("calude" -> 'claude): muy especificas, casi nunca coinciden por casualidad;
//   2) la palabra tal cual (fuzzy de fzf);
//   3) una letra de mas ("schhema" -> 'schema): coincidencias cortas, mas propensas al ruido ("clude" en
//      "include"), por eso van al final y solo cuentan si nada mas coincide.
// Operadores de fzf del usuario (!excluir, ^inicio, fin$, 'exacto) se dejan intactos.
function typoQuery(q) {
    return q.trim().split(/\s+/).filter(t => t !== "").map(t => {
        const tl = norm(t);
        if (tl.length < 4 || !/^[a-z0-9]+$/.test(tl)) return t;
        const swaps = [], dels = [];
        for (let i = 0; i < tl.length - 1; i++) {
            const v = tl.slice(0, i) + tl.charAt(i + 1) + tl.charAt(i) + tl.slice(i + 2);
            if (v !== tl && swaps.indexOf(v) < 0) swaps.push(v);
        }
        if (tl.length >= 5) for (let i = 0; i < tl.length; i++) {
            const v = tl.slice(0, i) + tl.slice(i + 1);
            if (dels.indexOf(v) < 0) dels.push(v);
        }
        return swaps.map(v => "'" + v).concat([tl], dels.map(v => "'" + v)).join(" | ");
    }).join(" ");
}

function typoTerms(terms, base, rel) {
    let total = 0;
    for (let i = 0; i < terms.length; i++) {
        const t = terms[i];
        let s = fuzzy(t, base);
        if (s >= 0) s += 10;
        else {
            s = pathScore(t, rel);
            if (s < 0) {
                if (t.length < 4) return -1;
                s = -1;
                for (const v of typoVariants(t)) {
                    if (base.indexOf(v) >= 0) { s = 22; break; }
                    if (rel.indexOf(v) >= 0) s = Math.max(s, 8);
                }
                if (s < 0) return -1;
            }
        }
        total += s;
    }
    return total - 15;                                  // una errata siempre queda por debajo de una coincidencia limpia
}

// --- Calculadora -----------------------------------------------------------------------------------
const FUNCS = { sqrt: "Math.sqrt", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan", asin: "Math.asin",
    acos: "Math.acos", atan: "Math.atan", log: "Math.log10", ln: "Math.log", abs: "Math.abs", exp: "Math.exp",
    floor: "Math.floor", ceil: "Math.ceil", round: "Math.round", pi: "Math.PI", e: "Math.E" };

function formatNumber(n) {
    if (!isFinite(n)) return String(n);
    if (Number.isInteger(n) && Math.abs(n) < 1e15) return String(n);
    const abs = Math.abs(n);
    if (abs !== 0 && (abs < 1e-6 || abs >= 1e15)) return n.toExponential(6).replace(/\.?0+e/, "e");
    return String(parseFloat(n.toPrecision(12)));
}

// Devuelve el texto del resultado o null si la consulta no es una cuenta.
function calc(query) {
    let q = query.trim();
    const forced = q.charAt(0) === "=";
    if (forced) q = q.slice(1).trim();
    if (q === "") return null;
    q = q.replace(/(\d),(\d)/g, "$1.$2").replace(/\^/g, "**").replace(/×/g, "*").replace(/÷/g, "/");
    // Solo numeros, operadores, parentesis y funciones conocidas.
    const tokens = q.match(/[a-z]+|\d+\.?\d*|\.\d+|\*\*|[-+*\/%()]|\s+|./gi) || [];
    let js = "", hasOp = false, hasDigit = false;
    for (const t of tokens) {
        if (/^\s+$/.test(t)) { js += " "; continue; }
        if (/^[a-z]+$/i.test(t)) {
            const f = FUNCS[t.toLowerCase()];
            if (!f) return null;
            js += f;
            if (t.toLowerCase() !== "pi" && t.toLowerCase() !== "e") hasOp = true; else hasDigit = true;
        } else if (/^(\d+\.?\d*|\.\d+)$/.test(t)) { js += t; hasDigit = true; }
        else if (/^(\*\*|[-+*\/%()])$/.test(t)) { js += t; if (t !== "(" && t !== ")") hasOp = true; }
        else return null;
    }
    if (!hasDigit || (!hasOp && !forced)) return null;
    try {
        const v = Function('"use strict"; return (' + js + ")")();
        if (typeof v !== "number" || !isFinite(v)) return null;
        return formatNumber(v);
    } catch (e) { return null; }
}

// --- Unidades ------------------------------------------------------------------------------------------
// [categoria, factor a la unidad base, nombres...]. Temperatura aparte.
const UNITS = [
    ["len", 0.001, "mm", "milimetro", "milimetros"],
    ["len", 0.01, "cm", "centimetro", "centimetros"],
    ["len", 1, "m", "metro", "metros"],
    ["len", 1000, "km", "kilometro", "kilometros"],
    ["len", 0.0254, "in", "inch", "pulgada", "pulgadas", "inches"],
    ["len", 0.3048, "ft", "foot", "feet", "pie", "pies"],
    ["len", 0.9144, "yd", "yarda", "yardas", "yard", "yards"],
    ["len", 1609.344, "mi", "milla", "millas", "mile", "miles"],
    ["mass", 0.001, "mg", "miligramo", "miligramos"],
    ["mass", 1, "g", "gramo", "gramos"],
    ["mass", 1000, "kg", "kilo", "kilos", "kilogramo", "kilogramos"],
    ["mass", 1e6, "t", "tonelada", "toneladas"],
    ["mass", 453.59237, "lb", "lbs", "libra", "libras", "pound", "pounds"],
    ["mass", 28.349523125, "oz", "onza", "onzas", "ounce", "ounces"],
    ["vol", 1, "ml", "mililitro", "mililitros"],
    ["vol", 1000, "l", "lt", "litro", "litros", "liter", "liters"],
    ["vol", 3785.411784, "gal", "galon", "galones", "gallon", "gallons"],
    ["vol", 946.352946, "qt", "cuarto", "cuartos"],
    ["vol", 29.5735295625, "floz", "fl oz"],
    ["vol", 236.5882365, "cup", "taza", "tazas"],
    ["time", 0.001, "ms"],
    ["time", 1, "s", "seg", "segundo", "segundos", "sec", "second", "seconds"],
    ["time", 60, "min", "minuto", "minutos", "minute", "minutes"],
    ["time", 3600, "h", "hr", "hora", "horas", "hour", "hours"],
    ["time", 86400, "d", "dia", "dias", "day", "days"],
    ["time", 604800, "sem", "semana", "semanas", "week", "weeks"],
    ["data", 1, "b", "byte", "bytes"],
    ["data", 1e3, "kb"], ["data", 1e6, "mb"], ["data", 1e9, "gb"], ["data", 1e12, "tb"],
    ["data", 1024, "kib"], ["data", 1048576, "mib"], ["data", 1073741824, "gib"], ["data", 1099511627776, "tib"],
    ["speed", 1, "m/s"],
    ["speed", 1 / 3.6, "km/h", "kmh", "kph"],
    ["speed", 0.44704, "mph"],
    ["speed", 0.514444, "kn", "nudo", "nudos", "kt"],
    ["area", 1, "m2", "m²"],
    ["area", 1e6, "km2", "km²"],
    ["area", 1e4, "ha", "hectarea", "hectareas"],
    ["area", 0.09290304, "ft2", "ft²"],
    ["area", 4046.8564224, "acre", "acres"],
];
const TEMPS = { c: ["c", "°c", "celsius", "grados c"], f: ["f", "°f", "fahrenheit", "grados f"], k: ["k", "kelvin"] };

const UNIT_INDEX = (function () {
    const idx = {};
    for (const u of UNITS) for (let i = 2; i < u.length; i++) idx[norm(u[i])] = u;
    return idx;
})();

function tempKind(name) {
    const n = norm(name);
    for (const k in TEMPS) if (TEMPS[k].indexOf(n) >= 0) return k;
    return null;
}
function toCelsius(v, k) { return k === "c" ? v : (k === "f" ? (v - 32) * 5 / 9 : v - 273.15); }
function fromCelsius(c, k) { return k === "c" ? c : (k === "f" ? c * 9 / 5 + 32 : c + 273.15); }

// "10 km en mi", "5 kg a lb", "20 c en f"  ->  { text: "10 km = 6.2137 mi", value: "6.2137" } o null
function convert(query) {
    const m = query.trim().match(/^(-?\d+(?:[.,]\d+)?)\s*([^\d\s][^]*?)\s+(?:en|a|to|in|->|=>)\s+(.+?)$/i);
    if (!m) return null;
    const v = parseFloat(m[1].replace(",", "."));
    const from = m[2].trim(), to = m[3].trim();
    const tf = tempKind(from), tt = tempKind(to);
    if (tf && tt) {
        const r = fromCelsius(toCelsius(v, tf), tt);
        const out = formatNumber(parseFloat(r.toFixed(4)));
        return { text: formatNumber(v) + " °" + tf.toUpperCase() + " = " + out + " °" + tt.toUpperCase(), value: out };
    }
    const a = UNIT_INDEX[norm(from)], b = UNIT_INDEX[norm(to)];
    if (!a || !b || a[0] !== b[0]) return null;
    const r = v * a[1] / b[1];
    const out = formatNumber(parseFloat(r.toPrecision(8)));
    return { text: formatNumber(v) + " " + a[2] + " = " + out + " " + b[2], value: out };
}

// --- Archivos ------------------------------------------------------------------------------------------------
const ICONS = [
    [/\.(png|jpe?g|gif|webp|bmp|svg|tiff?|heic|avif)$/i, "image-x-generic"],
    [/\.(mp4|mkv|webm|mov|avi|m4v)$/i, "video-x-generic"],
    [/\.(mp3|flac|ogg|opus|wav|m4a|aac)$/i, "audio-x-generic"],
    [/\.pdf$/i, "application-pdf"],
    [/\.(docx?|odt|rtf)$/i, "x-office-document"],
    [/\.(xlsx?|ods|csv)$/i, "x-office-spreadsheet"],
    [/\.(pptx?|odp)$/i, "x-office-presentation"],
    [/\.(zip|tar|gz|xz|bz2|7z|rar|zst|deb)$/i, "package-x-generic"],
    [/\.(sh|py|js|ts|qml|rs|c|cpp|h|java|go|rb|php|html|css|json|ya?ml|toml|kdl|md|txt|conf|log)$/i, "text-x-generic"],
];
function fileIcon(path) {
    for (const [re, icon] of ICONS) if (re.test(path)) return icon;
    return "text-x-generic";
}
function baseName(p) { return p.slice(p.lastIndexOf("/") + 1); }
function dirName(p) { const i = p.lastIndexOf("/"); return i > 0 ? p.slice(0, i) : "/"; }
function shortPath(p, home) { return home && p.indexOf(home) === 0 ? "~" + p.slice(home.length) : p; }
