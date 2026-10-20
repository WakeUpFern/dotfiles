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
la imagen se cambia en vivo con:

```bash
qs -c pill ipc call wallpaper set ~/Pictures/foto.png
```

La ruta queda guardada en `~/.local/state/pill/wallpaper` (prioridad: ese archivo > `PILL_WALLPAPER` > el valor por defecto de `Theme.qml`).

### Fondo del overview (`Mod+O`)

`Backdrop.qml` dibuja el *mismo* wallpaper, desenfocado (`MultiEffect`) y oscurecido, y la `layer-rule`
`place-within-backdrop` de niri lo muestra detrás de los workspaces solo en el overview. Como ambos leen
`Theme.wallpaper`, cambiar el fondo cambia los dos. Intensidad: `blurMax`, `brightness` y `saturation` en `Backdrop.qml`.

> Al **agregar un archivo QML nuevo** hay que reiniciar Quickshell (`qs -c pill kill && qs -c pill -d`);
> la recarga en caliente solo cubre cambios en archivos ya cargados.

## Animaciones, Alt+Tab y Overview

En `config/niri/config.kdl`:

- **Resortes con rebote** (`damping-ratio` < 1) en cambio de workspace, scroll horizontal, mover/redimensionar ventanas y overview. Para verlos en cámara lenta: `slowdown 2.0`.
- **Abrir ventana:** shader propio, curva easeOutBack (`cubic-bezier 0.34 1.56 0.64 1`): crece desde 80 %, rebota y sube unos píxeles. **Cerrar:** se encoge a 92 % y se desvanece. Si un shader falla, niri lo avisa en `journalctl --user -u niri` y usa el de por defecto.
- **Alt+Tab** (`recent-windows`): previews de las ventanas reales con resaltado redondeado en el color de acento. `Alt+Tab` todas las ventanas, `Alt+\`` solo las de la misma app.
- **Overview** (`Mod+O`): zoom 0.42 y fondo = wallpaper desenfocado (ver abajo).

## Blur xray vs. real

- **xray** (por defecto en niri): desenfoca solo el fondo de pantalla; barato, pero una ventana translúcida
  encima de otra *no* muestra a la de abajo, solo el wallpaper.
- **real** (`xray false`): desenfoca lo que de verdad hay debajo (apps, otras ventanas) en tiempo real.
  Cuesta más y en niri 26.04 es experimental: el blur desaparece durante las animaciones de abrir/cerrar
  ventana y al arrastrar una ventana en mosaico.

El notch usa el modo real (`layer-rule` en `config.kdl`). Las terminales siguen en xray; para que una
terminal flotante también desenfoque lo que tiene debajo, agrega `xray false` en su `background-effect`.

## Notificaciones

`Toast.qml`: una ventana layer-shell por tarjeta (capa Overlay, namespace `pill-toast`), para que el blur
real siga la forma de cada una (`layer-rule` en `config.kdl`). Entran desde la derecha con rebote
(`Easing.OutBack`, `overshoot` 2.2), salen con anticipación y las de abajo suben con resorte. Las críticas
llevan borde rojo y no se cierran solas. Pasar el ratón pausa el autocierre; click la descarta.
Tiempo por defecto: 6,5 s (o el que pida la app). Máximo 5 visibles.
