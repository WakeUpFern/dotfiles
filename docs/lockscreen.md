# Pantalla de bloqueo

Hay dos lockers. Se elige con `nativeLock` en `config/quickshell/pill/Theme.qml`:

| `nativeLock` | Locker | Estado |
|---|---|---|
| `false` | `swaylock`, con `config/swaylock/config` | probado |
| `true` (por defecto) | bloqueo propio del notch (`LockScreen.qml`) | probado con contraseña simulada y con la real (`lock-test.sh`) |

Se bloquea desde el menú de apagado (`Mod+Shift+E` → Bloquear), desde los botones del launcher o
con `Super+Alt+L`. Las tres rutas usan el locker elegido. `Super+Alt+Shift+L` abre siempre `swaylock`.

## Bloqueo propio

Reloj grande, fondo = tu wallpaper desenfocado y la contraseña como **figuras** (círculo, cuadrado,
triángulo, estrella, rombo) que saltan al teclear. Backspace las encoge, `Esc` o `Ctrl+U` borran todo.
Si la contraseña es incorrecta la caja se sacude, las figuras se ponen rojas y se desvanecen en cascada.
Si es correcta se ponen verdes y se desbloquea. Usa ext-session-lock + PAM (servicio `login`).

### Probarlo antes de activarlo

```bash
./scripts/lock-test.sh
```

Bloquea la pantalla con tu contraseña real y **se desbloquea sola a los 45 s** pase lo que pase.
Escribe tu contraseña y pulsa Enter: si las figuras aparecen al teclear y desbloquea, el teclado
llega bien y puedes activarlo con `nativeLock: true`. Si no escribe nada, espera los 45 s.

### Activarlo
En `Theme.qml`: `readonly property bool nativeLock: true` (Quickshell recarga solo).

## Salida de emergencia (si no puedes desbloquear)

No hace falta apagar el equipo. Desde un TTY:

1. `Ctrl+Alt+F3` → inicia sesión con tu usuario.
2. Lanza un locker nuevo y desbloquéalo con la señal:
   ```bash
   export WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u)
   pkill -x qs            # solo si el bloqueo propio sigue colgado
   swaylock -f
   pkill -USR1 swaylock
   ```
3. Vuelve a la sesión con `Ctrl+Alt+F2` (o `F1` si no aparece).

Si el bloqueo es una pantalla de color liso sin reloj ni anillo, el locker murió y niri mantiene la
sesión bloqueada por seguridad; el paso 2 la libera igual.

## swaylock

Config en `config/swaylock/config` (anillo siempre visible, colores del tema). Escribe la contraseña
a ciegas y Enter. Anillo azul = verificando, rojo = incorrecta, naranja = borrando.

Probarlo sin riesgo:

```bash
( sleep 10; pkill -USR1 swaylock ) & swaylock -i ~/Pictures/foto.png
```
