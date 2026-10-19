#!/usr/bin/env bash
# Prueba SEGURA del bloqueo propio: bloquea la pantalla con tu contrasena real y se
# desbloquea sola a los 45 s pase lo que pase. Sirve para comprobar que el teclado
# llega a la pantalla de bloqueo antes de usarla en serio.
#   ./scripts/lock-test.sh        # 45 s de seguridad
#   PILL_TEST_SECONDS=90 ./scripts/lock-test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "Bloqueando 45 s (o hasta que escribas tu contrasena y pulses Enter)..."
exec qs -p "$PWD/config/quickshell/pill/lock-test.qml"
