#!/usr/bin/env bash
# Compila e instala niri (+ xwayland-satellite) siguiendo docs/wiki/Packaging-niri.md de upstream.
# Deja niri como sesion seleccionable en GDM, junto a GNOME.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need_not_root
load_cargo
command -v cargo >/dev/null || die "No hay cargo. Corre scripts/02-rust.sh primero."

log "niri $NIRI_VERSION: descargando"
NIRI_DIR="$(fetch_repo https://github.com/niri-wm/niri.git niri "$NIRI_VERSION")"

log "niri: compilando (la primera vez tarda varios minutos)"
(cd "$NIRI_DIR" && NIRI_BUILD_COMMIT="$(git rev-parse --short HEAD)" cargo build --release --locked)

log "niri: instalando (sudo)"
sudo install -Dm755 "$NIRI_DIR/target/release/niri"          /usr/local/bin/niri
sudo install -Dm755 "$NIRI_DIR/resources/niri-session"       /usr/local/bin/niri-session
sudo install -Dm644 "$NIRI_DIR/resources/niri.desktop"       /usr/share/wayland-sessions/niri.desktop
sudo install -Dm644 "$NIRI_DIR/resources/niri-portals.conf"  /usr/share/xdg-desktop-portal/niri-portals.conf
sudo install -Dm644 "$NIRI_DIR/resources/niri.service"       /etc/systemd/user/niri.service
sudo install -Dm644 "$NIRI_DIR/resources/niri-shutdown.target" /etc/systemd/user/niri-shutdown.target

# GDM lanza Exec= sin PATH de usuario garantizado: usamos ruta absoluta.
sudo sed -i 's|^Exec=niri-session|Exec=/usr/local/bin/niri-session|' /usr/share/wayland-sessions/niri.desktop
sudo sed -i 's|^ExecStart=niri |ExecStart=/usr/local/bin/niri |'    /etc/systemd/user/niri.service

log "xwayland-satellite $XWAYLAND_SATELLITE_VERSION: descargando y compilando"
XS_DIR="$(fetch_repo https://github.com/Supreeeme/xwayland-satellite.git xwayland-satellite "$XWAYLAND_SATELLITE_VERSION")"
(cd "$XS_DIR" && cargo build --release --locked)
sudo install -Dm755 "$XS_DIR/target/release/xwayland-satellite" /usr/local/bin/xwayland-satellite
sudo apt-get install -y xwayland

systemctl --user daemon-reload || true
log "Instalado: $(niri --version)"
log "Cierra sesion y elige 'niri' en el selector de GDM (engranaje). GNOME sigue ahi como respaldo."
