#!/usr/bin/env bash
# Enlaza las configs del repo en ~/.config. Lo que ya exista se mueve a un respaldo.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need_not_root

BACKUP="$HOME/.config/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# origen (relativo a config/)  ->  destino (relativo a ~/.config)
LINKS=(
  "niri:niri"
  "quickshell/pill:quickshell/pill"
  "swaylock:swaylock"
)

for entry in "${LINKS[@]}"; do
  src="$REPO_DIR/config/${entry%%:*}"
  dst="$HOME/.config/${entry##*:}"
  [ -e "$src" ] || { warn "falta $src, lo salto"; continue; }
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    log "ya enlazado: $dst"; continue
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/$(echo "${entry##*:}" | tr / _)"
    warn "respaldado $dst -> $BACKUP"
  fi
  ln -s "$src" "$dst"
  log "enlazado: $dst -> $src"
done

# El agente polkit lo da Quickshell (PolkitDialog.qml). Solo puede haber uno por sesion, asi que se
# oculta el de mate-polkit (que solo arranca fuera de GNOME/KDE, o sea en niri). Para deshacerlo:
# borra ~/.config/autostart/polkit-mate-authentication-agent-1.desktop (y pon Theme.polkitAgent = false).
MATE_AGENT=/etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop
if [ -e "$MATE_AGENT" ]; then
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/polkit-mate-authentication-agent-1.desktop" <<'EOT'
[Desktop Entry]
Type=Application
Name=PolicyKit Authentication Agent (reemplazado por Quickshell)
Hidden=true
EOT
  log "agente polkit de mate desactivado (lo reemplaza Quickshell)"
fi

if command -v niri >/dev/null 2>&1; then
  log "Validando config de niri"
  niri validate -c "$HOME/.config/niri/config.kdl"
fi
