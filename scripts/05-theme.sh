#!/usr/bin/env bash
# Tema coherente para las apps: oscuro, iconos Papirus y cursor Adwaita. Todo a nivel de usuario (gsettings):
# GTK3/4 y libadwaita lo leen directamente; las apps Qt lo siguen con QT_QPA_PLATFORMTHEME=gtk3 (niri, bloque
# `environment`). El acento de GNOME lo va ajustando Quickshell con el fondo de pantalla (Theme.syncGtkAccent).
# Para deshacerlo:  gsettings reset-recursively org.gnome.desktop.interface
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need_not_root

command -v gsettings >/dev/null 2>&1 || die "Falta gsettings (paquete libglib2.0-bin)"

THEME_GTK="${THEME_GTK:-Adwaita-dark}"
THEME_ICONS="${THEME_ICONS:-Papirus-Dark}"
THEME_CURSOR="${THEME_CURSOR:-Adwaita}"
THEME_CURSOR_SIZE="${THEME_CURSOR_SIZE:-24}"

set_key() { gsettings set org.gnome.desktop.interface "$1" "$2" && log "$1 = $2"; }

set_key color-scheme prefer-dark
[ -d /usr/share/themes/$THEME_GTK ] && set_key gtk-theme "$THEME_GTK" || warn "no existe el tema GTK $THEME_GTK, lo dejo como esta"
if [ -d "/usr/share/icons/$THEME_ICONS" ] || [ -d "$HOME/.local/share/icons/$THEME_ICONS" ]; then
  set_key icon-theme "$THEME_ICONS"
else
  warn "no esta el tema de iconos $THEME_ICONS (paquete papirus-icon-theme), lo dejo como esta"
fi
set_key cursor-theme "$THEME_CURSOR"
set_key cursor-size "$THEME_CURSOR_SIZE"
log "Tema aplicado. Las apps Qt usan el tema GTK tras cerrar y abrir sesion (QT_QPA_PLATFORMTHEME en niri)."
