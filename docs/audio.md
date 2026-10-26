# Audio

Menú del icono de **volumen** (barra derecha). Rueda del ratón sobre el icono = volumen; clic central = silenciar.

| Sección | Qué hace |
|---|---|
| Volumen y salidas | volumen general y elegir la salida (altavoces, audífonos…) |
| **Aplicaciones** | una fila por app que esté reproduciendo: icono (clic = silenciar esa app), nombre, **salida actual** (clic para cambiarla), deslizador y porcentaje |
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

## Mover una app a otra salida

Con **más de una salida** conectada (altavoces + audífonos, HDMI…), bajo el nombre de cada app aparece la
salida por la que suena (`▸ Buds4 Pro…`). Un clic despliega la lista:

- Elegir una salida mueve **esa app** (todos sus flujos) sin tocar al resto ni la salida predeterminada.
- **↺ Seguir la salida predeterminada** quita el anclaje: la app vuelve a ir donde vaya el sonido del sistema.
- La elección se **recuerda por aplicación** (`~/.local/state/pill/audio-outputs`): al volver a abrir la app,
  o tras reiniciar sesión, vuelve a su salida si está conectada. Si no lo está (audífonos apagados), suena por la
  predeterminada y al reconectarlos se vuelve a aplicar a los flujos nuevos.
- Si los flujos de una app están en salidas distintas, se muestra `—`.

Para mover una app se escribe `target.object` en los metadatos de PipeWire (lo que hace `pw-metadata`);
WirePlumber recoloca el enlace al instante, sin cortar la reproducción.

## Cómo funciona

`AudioStreams.qml` enlaza todos los nodos de PipeWire (`PwObjectTracker`, necesario para leer sus
propiedades) y los clasifica por `media.class`: `Stream/Output/Audio` (apps que reproducen),
`Stream/Input/Audio` (apps que graban) y `Audio/Source` (micrófonos). Las propiedades llegan un instante
después de enlazar, por eso se crea al arrancar Quickshell.

Depuración: `qs -c pill ipc call audio apps | outputs | dump | mic | setapp <nombre> <0..1.5> | moveapp <nombre> <parte del nombre de la salida | auto>`.

> Ojo al probar: `qs -c pill kill` cierra **una** instancia y si hubo un cierre inesperado pueden quedar otras
> vivas con código antiguo (`qs list --all`). Para reiniciar limpio: `kill $(pgrep -x qs); qs -c pill -d`.
