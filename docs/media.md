# Reproductor multimedia

`Mod+M` abre el panel (la maximización a los bordes pasó a `Mod+Alt+M`). Habla MPRIS por
`Quickshell.Services.Mpris`, así que sirve con cualquier reproductor que lo implemente:
Spotify, navegadores (YouTube, etc.), VLC, mpv con el plugin mpris, Rhythmbox...

| Acción | Cómo |
|---|---|
| Pausa / reanudar | botón grande o `Espacio` |
| Pista siguiente / anterior | botones o `N` / `P` |
| Adelantar / atrasar 5 s | `→` / `←` |
| Ir a un punto | arrastrar la barra de progreso |
| Aleatorio / repetir | botones o `S` / `R` (repetir cicla: no, lista, pista) |
| Cambiar de reproductor | chips de abajo (aparecen si hay más de uno) |
| Cerrar | `Esc` o click fuera |

## Qué reproductor se controla

`MediaState.qml` elige el **activo**: el que elegiste a mano en los chips; si no, el que está sonando;
si no, el primero con pista. Las teclas multimedia (`XF86AudioPlay/Next/Prev`) pasan por Quickshell
(`qs -c pill ipc call media playpause|next|previous`), actúan sobre ese reproductor y muestran un HUD
con carátula, título y artista; si Quickshell no está corriendo, niri vuelve a `playerctl`.

### En el notch

- **Reposo:** mientras suena algo, a la derecha del notch aparecen unas barras animadas (estilo cava); un
  click sobre ellas abre el panel (igual que `Mod+M`).
- **Al pasar el ratón:** se despliega `♪ título — artista` y de dónde suena (`en Chrome`, `en Spotify`…).
- **Botón "anterior":** como en los reproductores normales, si la canción lleva más de 3 s la **reinicia**;
  si acaba de empezar, pasa a la pista anterior. Vale para el botón, la tecla `P`, las teclas multimedia
  del teclado y `qs -c pill ipc call media previous`.

### Las barras: cava o simuladas

Con [`cava`](https://github.com/karlstav/cava) instalado (`sudo apt install cava`; ya está en
`scripts/01-packages.sh`) muestran el **espectro real** del audio de la salida predeterminada
(`cava.conf`, modo `raw` por stdout). Sin `cava` se ven barras con un movimiento **simulado** (no
reaccionan al audio). Solo corren mientras suena algo y el notch es visible (no en pantalla completa), y se
actualizan sin interpolación por barra a propósito: interpolar a 60 fps costaba ~18 % de CPU; así ronda ~5 %.

## Notas

- MPRIS **no actualiza la posición solo**: el panel la consulta cada 400 ms mientras suena y está abierto.
- Si hay varios reproductores sonando a la vez, gana el primero; usa los chips para fijar otro.
- Las carátulas de navegadores suelen ser URLs remotas; si no cargan, se ve el icono de nota.

## Probar sin música

`python3 dev/mock_mpris.py` crea un reproductor falso ("Reproductor de prueba") con tres pistas, carátulas
generadas y posición en tiempo real, y registra cada comando que recibe en `/tmp/pill-mock/calls.log`.
Para apuntarle los controles sin tocar tus reproductores reales: `qs -c pill ipc call media select prueba`.
