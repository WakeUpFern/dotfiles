# Barra derecha y menús

Arriba a la derecha hay iconos **sin fondo** (con una sombra suave para que se lean sobre cualquier
ventana) agrupados en tres botones. El notch del centro se queda para lo dinámico (espacios de trabajo, app
activa, música, HUD de volumen/brillo, launcher, portapapeles, reproductor).

| Botón | Qué abre | ¿Parte del panel unificado? |
|---|---|---|
| **Ajustes rápidos** (candado de VPN, red, bluetooth, volumen, batería) | un solo panel con tiles y páginas de detalle (abajo) | **sí** |
| **Campana + reloj** | calendario del mes y debajo el historial de notificaciones con "No molestar" | no |
| Iconos de apps (bandeja) | click = acción de la app; click derecho = su menú (con nuestro estilo, con submenús) | no |

## Panel de ajustes rápidos

Como en GNOME, Windows 11 y macOS: **todo lo que es un ajuste del sistema vive en una sola tarjeta**; lo que
es otra cosa (avisos, fecha, apps en segundo plano) queda fuera.

- **Inicio:** batería, deslizador de volumen (clic en el icono = silenciar), brillo y tiles. Los tiles con
  flecha se activan/desactivan con la parte izquierda y abren su página con la flecha: **Red** (Wi-Fi o
  Ethernet), **Bluetooth**, **VPN** (solo si hay alguna), **No molestar**, **No suspender**, **Luz nocturna**, **Modo avión** y **Modo de energía**. Si una app
  usa el micrófono sale una línea naranja que lleva al mezclador.
- **Páginas:** Luz nocturna ([power.md](power.md#luz-nocturna)), Red ([network.md](network.md)), Bluetooth ([bluetooth.md](bluetooth.md)), Sonido (salidas,
  **volumen por aplicación** y **micrófono**, [audio.md](audio.md)), VPN y Batería y energía. Se vuelve con la
  flecha de la cabecera.
- **En la barra:** rueda sobre el botón = volumen y clic central = silenciar. Un candado azul = VPN activa.

- **Cambio directo:** con un menú abierto, pulsar otro icono cambia a ese; la tarjeta se redimensiona con
  resorte y el contenido hace un fundido (no se cierra ni parpadea).
- **Cerrar:** `Esc` o click en cualquier parte fuera de la barra y la tarjeta.
- **Pantalla completa:** la barra se esconde hacia arriba como el notch y baja si abres un menú.
- **Notificaciones:** las tarjetas salen bajo la barra y, con un menú abierto, **debajo de él**; al cerrarlo
  suben. Si no caben todas bajo el menú, entran las que caben (al menos una, la crítica siempre) y las demás
  esperan su turno.
- **Legibilidad:** al ser transparente, un icono claro sobre una ventana blanca se lee peor; la sombra
  ayuda. Si molesta, se puede añadir una banda tenue detrás (ver `StatusBar.qml`).

Abrir a mano: `qs -c pill ipc call popover toggle quick|network|bluetooth|volume|vpn|battery|notifications`
(los cinco primeros abren esa página del panel de ajustes rápidos; `clock` es lo mismo que `notifications`),
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
