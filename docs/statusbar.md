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
| Reloj | fecha y hora |

- **Cambio directo:** con un menú abierto, pulsar otro icono cambia a ese; la tarjeta se redimensiona con
  resorte y el contenido hace un fundido (no se cierra ni parpadea).
- **Cerrar:** `Esc` o click en cualquier parte fuera de la barra y la tarjeta.
- **Pantalla completa:** la barra se esconde hacia arriba como el notch y baja si abres un menú.
- **Notificaciones:** las tarjetas salen bajo la barra y, con un menú abierto, **debajo de él**; al cerrarlo
  suben. Si no caben todas bajo el menú, entran las que caben (al menos una, la crítica siempre) y las demás
  esperan su turno.
- **Legibilidad:** al ser transparente, un icono claro sobre una ventana blanca se lee peor; la sombra
  ayuda. Si molesta, se puede añadir una banda tenue detrás (ver `StatusBar.qml`).

Abrir a mano: `qs -c pill ipc call popover toggle bluetooth|volume|battery|clock`.
