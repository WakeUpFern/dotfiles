# Tema: frosted glass

Dos capas de blur, ambas nativas (niri >= 26.04):

1. **Ventanas** (`config/niri/config.kdl`): regla con `opacity 0.80` + `background-effect { blur true }`.
   De momento solo aplica a terminales (Alacritty, foot, kitty, wezterm, ghostty); para sumar más apps
   se agrega otro `match app-id=...` (el app-id sale de `niri msg windows`).
2. **Píldora** (`Pill.qml`): `BackgroundEffect.blurRegion` (protocolo `ext-background-effect`)
   con la forma exacta del rectángulo animado, sin reglas en niri.

Ajustes globales de intensidad: bloque `blur { passes offset noise saturation }`.

El `focus-ring` está apagado porque se dibuja *debajo* de la ventana y tapa el blur;
se usa `border` fino en su lugar.

Colores/fuentes/tiempos de la píldora: `config/quickshell/pill/Theme.qml`.

## Fondo de pantalla (requisito del blur)

El blur de niri desenfoca el *fondo de pantalla* (capa Background). Sin fondo no hay nada que
desenfocar y la ventana solo se ve gris translúcida. `Wallpaper.qml` lo dibuja con Quickshell;
la imagen se cambia en `Theme.qml` (`wallpaper`) o al vuelo con `PILL_WALLPAPER=/ruta.png qs -c pill`.

> Al **agregar un archivo QML nuevo** hay que reiniciar Quickshell (`qs -c pill kill && qs -c pill -d`);
> la recarga en caliente solo cubre cambios en archivos ya cargados.
