# Tema: frosted glass

Dos capas de blur, ambas nativas (niri >= 26.04):

1. **Ventanas** (`config/niri/config.kdl`): regla global con `opacity 0.88` + `background-effect { blur true }`.
   Las apps de video/navegador se excluyen en la regla siguiente para que no se vean translúcidas.
2. **Píldora** (`Pill.qml`): `BackgroundEffect.blurRegion` (protocolo `ext-background-effect`)
   con la forma exacta del rectángulo animado, sin reglas en niri.

Ajustes globales de intensidad: bloque `blur { passes offset noise saturation }`.

El `focus-ring` está apagado porque se dibuja *debajo* de la ventana y tapa el blur;
se usa `border` fino en su lugar.

Colores/fuentes/tiempos de la píldora: `config/quickshell/pill/Theme.qml`.
