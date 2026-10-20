#!/usr/bin/env bash
# Prueba SEGURA del bloqueo propio: bloquea la pantalla con tu contrasena real y se
# desbloquea sola a los 45 s pase lo que pase. Sirve para comprobar que el teclado
# llega a la pantalla de bloqueo antes de usarla en serio.
#   ./scripts/lock-test.sh        # 45 s de seguridad
#   PILL_TEST_SECONDS=90 ./scripts/lock-test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# Dos instancias a la vez se disputan el mismo bloqueo y el temporizador de seguridad deja de servir.
if pgrep -f 'quickshell/pill/[l]ock-test.qml' >/dev/null; then
  echo "Ya hay una prueba de bloqueo en marcha; espera a que termine." >&2
  exit 1
fi
echo "Bloqueando 45 s (o hasta que escribas tu contrasena y pulses Enter)..."
exec qs -p "$PWD/config/quickshell/pill/lock-test.qml"
