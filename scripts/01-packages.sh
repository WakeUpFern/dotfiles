#!/usr/bin/env bash
# Paquetes de apt: dependencias de compilacion, runtime de la sesion y Quickshell.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need_not_root

BUILD_DEPS=(
  build-essential pkg-config clang libclang-dev cmake ninja-build git curl ca-certificates
  libwayland-dev libxkbcommon-dev libinput-dev libseat-dev libdisplay-info-dev
  libpipewire-0.3-dev libpango1.0-dev libgbm-dev libudev-dev libdbus-1-dev libsystemd-dev
  libegl-dev libgles2-mesa-dev libglib2.0-dev libcairo2-dev
  libxcb1-dev libxcb-cursor-dev libxcb-xfixes0-dev libxcb-icccm4-dev libxcb-res0-dev libxcb-util-dev
)

# Sesion: portales, polkit, audio, red, energia. En la mayoria ya vienen con GNOME.
RUNTIME=(
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk
  pipewire wireplumber pipewire-pulse
  network-manager bluez upower power-profiles-daemon
  dbus-user-session polkitd mate-polkit
  wl-clipboard cliphist grim slurp brightnessctl playerctl libnotify-bin xdg-utils
  swaylock wlsunset
  alacritty
  cava
)

# Qt6/QML que usa Quickshell para dibujar la pildora.
QML=(
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts
  qml6-module-qtquick-effects qml6-module-qt5compat-graphicaleffects
)

FONTS=(fonts-inter fonts-jetbrains-mono fonts-noto-color-emoji fonts-font-awesome papirus-icon-theme)

log "Actualizando indices de apt"
sudo apt-get update

log "Instalando dependencias (compilacion, runtime, QML, fuentes)"
sudo apt-get install -y "${BUILD_DEPS[@]}" "${RUNTIME[@]}" "${QML[@]}" "${FONTS[@]}"

# Quickshell no esta en trixie, pero si en trixie-backports.
log "Instalando Quickshell desde trixie-backports"
sudo apt-get install -y -t trixie-backports quickshell

log "Listo: $(qs --version 2>/dev/null || echo 'quickshell instalado')"
