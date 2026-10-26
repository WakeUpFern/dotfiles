# Diálogos: por qué salían al lado y cómo flotan ahora

**Es el comportamiento esperado en niri** (y en Hyprland y otros): un compositor de mosaico coloca
cada ventana nueva en el diseño. niri solo hace flotar y centrar automáticamente las ventanas que
**declaran un padre** (`xdg_toplevel.set_parent` o `xdg-foreign`), que es lo que hace un diálogo
modal normal. Pero el **selector de archivos** y los avisos de **permisos** los abre otro proceso
(el portal de escritorio: `xdg-desktop-portal-gnome` / `-gtk`), y muchas apps (Electron, LibreOffice,
Chrome según la versión…) no le pasan quién es el padre. Resultado: niri los trata como una ventana
cualquiera y abre una columna nueva junto a la tuya.

## La regla (`config/niri/config.kdl`)

Una `window-rule` con `open-floating true` + centrado + tamaño cómodo (900×640) para:

- **Selector de archivos** (`org.gnome.Nautilus`) cuando el título empieza por un verbo típico de
  diálogo, en inglés o español: *Open, Save, Select, Choose, Upload, Attach, Insert, Import, Export,
  Add / Abrir, Guardar, Seleccionar, Elegir, Subir, Adjuntar, Insertar, Importar, Exportar, Añadir*.
- **Ventanas de los portales** `org.freedesktop.impl.portal.desktop.gtk|gnome` y
  `xdg-desktop-portal-gtk|gnome` (avisos de permisos, selector de color…).

## Límites

- Se detecta **por título**, porque el selector es una ventana de Nautilus con el título que le dé la app
  y no hay otra forma de distinguirla de una ventana normal de Nautilus. Si una app lo titula de otra manera
  (p. ej. "Elige una imagen"), saldrá en mosaico.
- **Arreglo rápido** para uno suelto: `Mod+Alt+V` lo pasa a flotante. **Arreglo permanente:** `niri msg windows`
  con el diálogo abierto muestra su `app-id` y título; añade su título (o `app-id`) a la regla.
- Los diálogos que sí declaran padre ya flotaban solos; la regla no los afecta.
- Alternativa más fiable pero más invasiva: usar el portal GTK para el selector de archivos
  (`org.freedesktop.impl.portal.FileChooser=gtk;` en `~/.config/xdg-desktop-portal/niri-portals.conf`), cuya
  ventana tiene un `app-id` propio. No está aplicada: exige reiniciar el portal (corta capturas de pantalla
  compartidas en curso) y cambia el aspecto del selector.

Probar sin una app: `gdbus call --session --dest org.freedesktop.portal.Desktop --object-path
/org/freedesktop/portal/desktop --method org.freedesktop.portal.FileChooser.OpenFile "" "Open File" "{}"`.
