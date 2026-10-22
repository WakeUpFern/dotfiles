#!/usr/bin/env python3
"""Genera config/quickshell/pill/emoji.json (selector de emoji) a partir del diccionario de GTK4.

Uso:  scripts/gen-emoji.py [ruta/a/es.gresource]
Por defecto busca el es.gresource del runtime de GNOME de flatpak. El mismo archivo existe en el paquete de
GTK4 de cualquier distro (share/gtk-4.0/emoji/es.gresource). Los datos son del CLDR (licencia Unicode).

Salida: {"groups": [...], "tones": [...], "emoji": [[texto, nombre_es, buscar, grupo, tono], ...]}
  - nombre_es  : nombre en espanol
  - buscar     : nombre en ingles + palabras clave (para buscar tambien en ingles)
  - grupo      : indice en "groups"
  - tono       : 1 si admite tono de piel (el texto trae U+E000 donde va el tono)
"""
import glob, json, subprocess, sys, os, tempfile
import gi
gi.require_version("GLib", "2.0")
from gi.repository import GLib

GLOBS = ["/var/lib/flatpak/runtime/org.gnome.Platform/*/*/active/files/share/gtk-4.0/emoji/es.gresource",
         "/usr/share/gtk-4.0/emoji/es.gresource", "/usr/share/gtk-4/emoji/es.gresource"]
path = sys.argv[1] if len(sys.argv) > 1 else next((p for g in GLOBS for p in sorted(glob.glob(g))), None)
if not path or not os.path.exists(path):
    sys.exit("No encuentro es.gresource: pasa su ruta como argumento")

res = subprocess.check_output(["gresource", "list", path], text=True).split()[0]
data = subprocess.check_output(["gresource", "extract", path, res])
v = GLib.Variant.new_from_bytes(GLib.VariantType("a(aussasu)"), GLib.Bytes.new(data), False)

# El archivo viene en el orden de grupos de Unicode; cada grupo empieza en estos emoji (nombre en ingles).
GROUPS = [
    ("Caras y emociones", "grinning face"),
    ("Personas y cuerpo", "waving hand"),
    ("Animales y naturaleza", "monkey face"),
    ("Comida y bebida", "grapes"),
    ("Viajes y lugares", "globe showing Europe-Africa"),
    ("Actividades", "jack-o-lantern"),
    ("Objetos", "glasses"),
    ("Símbolos", "ATM sign"),
    ("Banderas", "chequered flag"),
]
TONES = set(range(0x1F3FB, 0x1F400))

# GTK guarda los emoji con tono de piel una sola vez, con un "hueco" para el tono: el modificador de tono
# claro (1F3FB) o un 0. Aqui el hueco se escribe como U+E000; el selector lo cambia por el tono elegido
# (o lo quita para el tono por defecto).
SLOT = "\ue000"

rows = [(list(cps), en, es, list(kw)) for cps, en, es, kw, _ in v]

group_at = {}
for gi_, (_, marker) in enumerate(GROUPS):
    pos = next((i for i, r in enumerate(rows) if r[1] == marker and i not in group_at), None)
    if pos is None:
        sys.exit(f"No encuentro el inicio del grupo {marker!r}")
    group_at[pos] = gi_

out, cur = [], 0
for i, (cps, en, es, kw) in enumerate(rows):
    cur = group_at.get(i, cur)
    tone = int(any(c == 0 or c in TONES for c in cps))
    text = "".join(SLOT if (c == 0 or c in TONES) else chr(c) for c in cps)
    search = " ".join(dict.fromkeys([en] + kw)).lower()
    out.append([text, es or en, search, cur, tone])

json.dump({"groups": [g for g, _ in GROUPS], "tones": [chr(t) for t in sorted(TONES)], "emoji": out},
          open(os.path.join(os.path.dirname(__file__), "..", "config/quickshell/pill/emoji.json"), "w"),
          ensure_ascii=False, separators=(",", ":"))
print(f"{len(out)} emoji, {sum(1 for o in out if o[4])} con tono de piel")
