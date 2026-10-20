# Bluetooth

Sección `bt` del **panel de controles** (click en el notch → volumen/luz/batería, o click en `bt …` en la
fila que aparece al pasar el ratón cuando hay algo conectado).

| Elemento | Qué hace |
|---|---|
| Interruptor | enciende / apaga el adaptador |
| **Buscar** | busca dispositivos nuevos (aparecen con la etiqueta "Nuevo") |
| Fila de un dispositivo | click = conectar; si está conectado, click = desconectar; si es nuevo, lo empareja, lo marca de confianza y lo conecta |
| Resumen | nombres de lo conectado con su batería (si el dispositivo la reporta) |

Se muestran como máximo 4 dispositivos: primero los conectados, luego los emparejados y, mientras buscas,
los nuevos. Al conectar unos audífonos, PipeWire cambia solo la salida de audio; la lista de salidas del
mismo panel (arriba) muestra cuál quedó activa y permite cambiarla.

Usa `Quickshell.Bluetooth` (BlueZ por D-Bus), sin `bluetoothctl` ni herramientas externas.
