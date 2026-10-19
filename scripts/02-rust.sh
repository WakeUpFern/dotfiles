#!/usr/bin/env bash
# Instala la toolchain de Rust con rustup (niri v26.04 pide un rustc mas nuevo que el de apt).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need_not_root

load_cargo
if command -v rustup >/dev/null 2>&1; then
  log "rustup ya esta instalado; actualizando stable"
  rustup update stable
else
  log "Instalando rustup (perfil minimal, toolchain stable)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
fi
load_cargo
log "$(rustc --version) / $(cargo --version)"
