# Capturas, grabación de pantalla y selector de emoji

## Capturas y grabación (`ScreenCapture.qml`, `CapturePage.qml`)
Panel **Mod+Shift+S** (o el botón de la cámara, arriba a la derecha del panel de ajustes rápidos; `qs -c pill ipc call popover toggle capture`):

| Botón | Qué hace |
|---|---|
| Selección | abre la interfaz de selección de niri (arrastra un área; Espacio alterna el puntero) |
| Ventana / Pantalla | captura la ventana enfocada / la pantalla enfocada |
| Retardo (Ya, 3, 5, 10 s) | espera antes de capturar (el panel se cierra siempre antes para no salir en la foto) |
| Incluir el puntero | `--show-pointer` |
| Grabar pantalla / selección | graba un `.mp4` con `wf-recorder` en `~/Videos` |

- Las capturas las hace **niri**: se guardan según `screenshot-path` de `config/niri/config.kdl`
  (`~/Pictures/Screenshots`) y se copian al portapapeles. Las teclas `Print`, `Ctrl+Print` y `Alt+Print` siguen
  haciendo lo mismo directamente.
- **Grabación:** requiere `wf-recorder` y `slurp` (`sudo apt install wf-recorder slurp`; el instalador ya los
  incluye). Mientras graba sale un punto rojo parpadeante en la barra y otro en el botón de la cámara, y la
  página tiene el tiempo y *Detener*; al terminar avisa con la ruta del archivo. Sin audio por ahora.
- IPC: `qs -c pill ipc call capture area|window|screen|record|recordarea|stop|status`.

## Selector de emoji (`EmojiPanel.qml`, `EmojiData.qml`)
**Mod+;** abre el selector en el notch (`qs -c pill ipc call emoji toggle`).
- Escribe para buscar por **nombre en español o inglés** o palabras clave ("risa", "heart", "pizza"). Sin texto
  ves las categorías (🕘 recientes, 😀 caras, 👋 personas, 🐵 animales, 🍇 comida, 🌍 viajes, 🎃 actividades,
  👓 objetos, 🏧 símbolos, 🏁 banderas); **Tab** cambia de categoría.
- Flechas para moverte, **Enter** o clic para elegir, Esc cierra.
- El emoji se **copia** al portapapeles y, si tienes `wtype` instalado (`sudo apt install wtype`; el instalador
  lo incluye), se **escribe directamente** en la app que tenías enfocada. Sin `wtype` avisa "Copiado, pega con
  Ctrl+V".
- Los círculos de abajo eligen el **tono de piel** (afecta a los emoji que lo admiten). Recientes y tono se
  guardan en `~/.local/state/pill/emoji`.
- Los datos están en `config/quickshell/pill/emoji.json` (1918 emoji, nombres del CLDR). Se regeneran con
  `scripts/gen-emoji.py [ruta/a/es.gresource]` a partir del diccionario de GTK4 (necesita `python3-gi` y
  `gresource`).
