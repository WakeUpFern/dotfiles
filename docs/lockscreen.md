# Pantalla de bloqueo

Usa `swaylock` (config en `config/swaylock/config`, enlazada a `~/.config/swaylock/config`).
Se abre desde el menú de apagado (`Mod+Shift+E` → Bloquear), desde los botones del launcher
o con `Super+Alt+L`. Las tres rutas ejecutan el mismo comando.

- El **anillo** del centro está siempre visible: es donde se "escribe". No hay campo de texto;
  teclea la contraseña a ciegas (cada tecla ilumina un segmento del anillo) y pulsa **Enter**.
- Anillo **azul** = verificando, **rojo** = contraseña incorrecta, **naranja** = borrando.
- Con Bloq Mayús activo el anillo lo indica.
- Las contraseñas vacías se ignoran.

## Salida de emergencia (si no puedes desbloquear)

No hace falta apagar el equipo. Desde un TTY se le envía la señal de desbloqueo a swaylock:

1. `Ctrl+Alt+F3` → inicia sesión con tu usuario en el TTY.
2. `pkill -USR1 swaylock`
3. Vuelve a la sesión con `Ctrl+Alt+F2` (o `F1` si no aparece).

Si el bloqueo quedó como una pantalla de color liso sin anillo, el locker murió y niri mantiene
la sesión bloqueada por seguridad. Desde el TTY se arregla lanzando uno nuevo y desbloqueándolo:

```bash
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u) swaylock -f
pkill -USR1 swaylock
```

## Probarlo sin riesgo

Lanza el bloqueo con un desbloqueo automático por si algo falla:

```bash
( sleep 10; pkill -USR1 swaylock ) & swaylock -i ~/Pictures/foto.png
```
