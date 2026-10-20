# Audio

Menú del icono de **volumen** (barra derecha). Rueda del ratón sobre el icono = volumen; clic central = silenciar.

| Sección | Qué hace |
|---|---|
| Volumen y salidas | volumen general y elegir la salida (altavoces, audífonos…) |
| **Aplicaciones** | una fila por app que esté reproduciendo: icono (clic = silenciar esa app), nombre, deslizador y porcentaje |
| **Micrófono** | volumen y silencio de la entrada predeterminada; clic en su nombre para cambiar de micrófono |
| Brillo | brillo de la pantalla |

## Cosas a saber

- **El volumen de cada app es independiente del general**: si una app está al 40 % y el general al 50 %,
  oyes el producto (como en `pavucontrol`). Hasta 150 %.
- Las apps aparecen **mientras tengan audio abierto** (Chrome crea un flujo por cada pestaña que suena;
  aquí se agrupan en una fila, "N flujos").
- **Micrófono en uso:** un punto naranja junto al icono de volumen y "En uso: app" en la sección del
  micrófono cuando alguna app tiene una grabación abierta. Cuenta que el flujo *exista* (puede estar en
  pausa). Se ignoran los flujos que escuchan una **salida** (visualizadores como cava, grabadores de
  pantalla), que PipeWire marca con `stream.capture.sink`.
- Mover una app a otra salida no está hecho todavía (solo su volumen).

## Cómo funciona

`AudioStreams.qml` enlaza todos los nodos de PipeWire (`PwObjectTracker`, necesario para leer sus
propiedades) y los clasifica por `media.class`: `Stream/Output/Audio` (apps que reproducen),
`Stream/Input/Audio` (apps que graban) y `Audio/Source` (micrófonos). Las propiedades llegan un instante
después de enlazar, por eso se crea al arrancar Quickshell.

Depuración: `qs -c pill ipc call audio apps | dump | mic | setapp <nombre> <0..1.5>`.
