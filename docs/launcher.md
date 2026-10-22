# Launcher (Mod+D)

Un solo cuadro que busca en todo a la vez. Escribe y salen, por secciones:

| Sección | Qué es |
|---|---|
| **Resultado** | una cuenta (`2*(3+4)^2`, `sqrt(16)`, `15,5*2`) o una conversión (`10 km en mi`, `5 kg a lb`, `20 c en f`, `3 horas en min`, `60 mph a km/h`). Enter copia el resultado. |
| **Aplicaciones** | por nombre, descripción, categoría ("explorador", "navegador"), alias en español y abreviaturas (`ffx` → Firefox). Las que más usas suben. |
| **Archivos** | por nombre o ruta, difuso (`wlhv` → wallhaven…), con **varias palabras** (`informe 2024`, `dotfiles launcher`) y **tolerante a erratas** (`shcema` → `schema`). Suben los que abres seguido y los modificados hace poco. Enter abre; **Ctrl+Enter** abre la carpeta; clic derecho también. |
| **En documentos** | el **contenido** de tus documentos (PDF, LibreOffice, Markdown…) con un fragmento, vía el indexador de GNOME (`localsearch`). Solo cubre lo que ese indexador vigila (Documentos, Descargas, Imágenes…). |

Si no coincide nada, ofrece buscarlo en la web (`Theme.launcherDefaultSearch`).

## Prefijos
- `> comando` ejecuta el comando; **Ctrl+Enter** lo ejecuta en una terminal (alacritty, la deja abierta).
- `g texto` Google · `d` DuckDuckGo · `yt` YouTube · `w` Wikipedia · `gh` GitHub · `m` Maps (se editan o amplían en
  `Theme.launcherWebSearches`).
- `f texto` solo archivos (14 resultados en lugar de 6).
- `= expresión` fuerza el modo cuenta. Una URL (`https://…`, `www.…`) se abre directamente.

## Sin texto
Pestañas **Fijadas** (cuadrícula; clic derecho o Ctrl+P fija/desfija), **Recientes** (las apps que abriste desde
aquí, por orden) y **Todas** (A-Z). **Tab** cambia de pestaña. El uso se guarda en
`~/.local/state/pill/launcher-usage`, las fijadas en `pinned-apps`.

## Motor de búsqueda: fzf
El launcher usa **fzf** (`sudo apt install fzf`, lo incluye el instalador), el estándar de facto de búsqueda difusa,
en modo filtro (`fzf --filter`). Sin fzf cae automáticamente a un puntuador interno equivalente (`LauncherLogic.js`),
así que nunca se queda sin buscador.
- **Apps:** fzf busca solo en el **nombre** (y el final del id); las palabras clave, categorías y alias en español
  (`explorador` → Files) se resuelven aparte por coincidencia directa. Van ordenadas por uso (desempata fzf).
- **Archivos:** `find` lista tu home (~150 ms, sin ocultos ni `Theme.fileSearchExcludes`) en
  `$XDG_RUNTIME_DIR/pill-files.tsv` y fzf filtra ese archivo (`--scheme path`). Se relee al abrir el launcher si
  tiene más de un minuto; sin demonio ni base de datos. A lo que ordena fzf se suman los archivos que abres
  seguido y los modificados hace poco.
- **Sintaxis de fzf** (funciona en el cuadro tal cual): `'exacto`, `^inicio`, `fin$`, `!excluir`, `a | b`; varias
  palabras separadas por espacio = todas deben coincidir.
- **Erratas:** fzf no las tolera (`calude` no encuentra `claude`: las letras deben ir en orden). Se suman en la
  misma pasada: cada palabra de 4+ letras viaja como `'cambiadas | palabra | 'letra-de-más`. fzf usa la primera
  alternativa que coincide, así que el orden importa: primero las letras cambiadas de sitio (`'claude`, muy
  específicas), luego la palabra tal cual, y al final las de una letra de más (`'schema` para `schhema`), que dan
  más ruido (`clude` aparece en "include"). Una coincidencia exacta puntúa muy por encima de una dispersa.
- **Orden final:** cada posición de fzf vale 5 puntos; la recencia (máx. 4) y el uso solo desempatan o suben un
  poco lo que abres seguido.
- Como fzf es fuzzy de verdad, una consulta corta puede traer coincidencias dispersas (p. ej. `andar` → Calendar):
  van abajo, por puntuación. Si algo molesta, el puntuador interno es más estricto: quita fzf y se usa ese.
- Cambiar de binario: `Theme.fzfCommand`.

## Probar sin teclado
`qs -c pill ipc call launcher search "f informe"` abre el launcher ya escrito (sirve también para atajos de niri).
La lógica pura (cuentas, unidades, puntuación) se prueba con node: ver el principio de `LauncherLogic.js`.
