# Helpers compartidos por los scripts de instalacion. Se usa con `source`.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${SRC_DIR:-$HOME/.local/src}"

# Versiones fijadas: cambiarlas aqui y volver a correr el script del paso.
NIRI_VERSION="${NIRI_VERSION:-v26.04}"
XWAYLAND_SATELLITE_VERSION="${XWAYLAND_SATELLITE_VERSION:-v0.8.3}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

need_not_root() { [ "$(id -u)" -ne 0 ] || die "Corre esto como tu usuario, no como root (usa sudo solo donde haga falta)."; }

# Clona (o actualiza) un repo en SRC_DIR y deja checkout del tag pedido.
# uso: fetch_repo <url> <nombre> <tag>
fetch_repo() {
  local url="$1" name="$2" tag="$3" dir="$SRC_DIR/$2"
  mkdir -p "$SRC_DIR"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch --tags --force --quiet
  else
    git clone --quiet "$url" "$dir"
  fi
  git -C "$dir" checkout --quiet "$tag"
  echo "$dir"
}

# Carga cargo si rustup lo instalo en este mismo shell.
load_cargo() { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; return 0; }
