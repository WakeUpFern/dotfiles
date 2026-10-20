# Barra derecha y menús

Arriba a la derecha hay iconos **sin fondo** (con una sombra suave para que se lean sobre cualquier
ventana) y el reloj: Bluetooth, volumen, batería. Cada uno abre **su propio menú**, una tarjeta de vidrio
anclada bajo la barra. El notch del centro se queda para lo dinámico (espacios de trabajo, app activa, música,
HUD de volumen/brillo, launcher, portapapeles, reproductor).

| Icono | Menú |
|---|---|
| Bluetooth | interruptor, buscar, dispositivos, calidad del audio ([bluetooth.md](bluetooth.md)) |
| Volumen | deslizador, salidas de audio y brillo de pantalla |
| Batería | nivel, estado, tiempo restante y perfil de energía |
| Campana | historial de notificaciones, "No molestar" y borrar todo |
| Reloj | fecha y hora |
| Iconos de apps (bandeja) | click = acción de la app; click derecho = su menú (con nuestro estilo, con submenús) |

- **Cambio directo:** con un menú abierto, pulsar otro icono cambia a ese; la tarjeta se redimensiona con
  resorte y el contenido hace un fundido (no se cierra ni parpadea).
- **Cerrar:** `Esc` o click en cualquier parte fuera de la barra y la tarjeta.
- **Pantalla completa:** la barra se esconde hacia arriba como el notch y baja si abres un menú.
- **Notificaciones:** las tarjetas salen bajo la barra y, con un menú abierto, **debajo de él**; al cerrarlo
  suben. Si no caben todas bajo el menú, entran las que caben (al menos una, la crítica siempre) y las demás
  esperan su turno.
- **Legibilidad:** al ser transparente, un icono claro sobre una ventana blanca se lee peor; la sombra
  ayuda. Si molesta, se puede añadir una banda tenue detrás (ver `StatusBar.qml`).

Abrir a mano: `qs -c pill ipc call popover toggle bluetooth|volume|battery|notifications|clock`,
`qs -c pill ipc call tray list` y `... tray menu <n>`.

## Campana: historial y "No molestar"

- Cada notificación se guarda (hasta 50, **en memoria**: se vacían al reiniciar Quickshell) y suma al contador
  rojo de la campana; abrir el menú las marca como leídas y cierra las tarjetas que siguieran en pantalla.
- Click en una entrada = ir a la ventana de esa app y quitarla de la lista; la ✕ solo la quita.
- **No molestar** (interruptor del menú o `qs -c pill ipc call notifications dnd`): no salen tarjetas, pero
  todo queda en el historial y en el contador. Las críticas sí salen. La campana se cambia a "tachada".
- `qs -c pill ipc call notifications clear` borra el historial y las tarjetas.

## Bandeja del sistema

Quickshell actúa como *StatusNotifierWatcher* y *Host*: las apps que usen ese estándar (LocalSend, Telegram,
Discord, gestores de red, etc.) aparecen como iconos a la izquierda de la barra. Las apps que ya estaban
abiertas cuando Quickshell arrancó pueden no registrarse hasta que las reinicies.
