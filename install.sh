#!/usr/bin/env bash
# Instalador completo: ./install.sh            -> todos los pasos
#                      ./install.sh niri link  -> solo pasos concretos
set -euo pipefail
cd "$(dirname "$0")"

declare -A STEPS=(
  [packages]=scripts/01-packages.sh
  [rust]=scripts/02-rust.sh
  [niri]=scripts/03-niri.sh
  [link]=scripts/04-link.sh
  [theme]=scripts/05-theme.sh
)
ORDER=(packages rust niri link theme)

for s in "${@:-${ORDER[@]}}"; do
  [ -n "${STEPS[$s]:-}" ] || { echo "Paso desconocido: $s (opciones: ${ORDER[*]})" >&2; exit 1; }
  bash "${STEPS[$s]}"
done
