# dotfiles - niri + Quickshell en Debian 13

Rice para Debian 13 (trixie). Un solo compositor (**niri**) y un solo shell
(**Quickshell**): un *notch* pegado al borde superior (estilo Mac) que hace de barra,
launcher, HUD de volumen y panel de estado, con animaciones de resorte. Estética inicial: vidrio esmerilado (blur nativo de niri).

**¿Bloqueaste la pantalla y no puedes entrar?** Mira [docs/lockscreen.md](docs/lockscreen.md): hay salida desde un TTY sin apagar el equipo.

GNOME se queda instalado como sesión de respaldo (ver [docs/gnome-fallback.md](docs/gnome-fallback.md)).

## Instalar

```bash
git clone <este-repo> ~/dotfiles && cd ~/dotfiles
./install.sh            # todos los pasos
./install.sh niri link  # o pasos sueltos: packages | rust | niri | link
```

| Paso | Qué hace |
|------|----------|
| `packages` | apt: dependencias de compilación, portales, audio, fuentes, y Quickshell desde `trixie-backports` |
| `rust` | rustup (el rustc de apt es viejo para niri) |
| `niri` | compila niri y xwayland-satellite (versiones fijadas en `scripts/lib.sh`), los instala en `/usr/local` y registra la sesión en GDM |
| `link` | enlaza `config/*` en `~/.config` (respalda lo que haya) |

Después: cerrar sesión → engranaje de GDM → **niri**.

## Estructura

```
config/niri/config.kdl          compositor: layout, binds, blur, reglas de ventana
config/quickshell/pill/         la píldora (QML)
  shell.qml                     entrada: notificaciones, IPC, modo actual
  Pill.qml                      el notch: ventana, animaciones, icono de app activa, OSD, estado
  Wallpaper.qml                 fondo de pantalla (capa Background; necesario para el blur)
  Backdrop.qml                  mismo fondo, desenfocado, para el overview (Mod+O)
  Launcher.qml                  buscador de apps + fila de energia
  PowerMenu.qml / PowerButton.qml / PowerActions.qml   menu de apagado (apagar, reiniciar, suspender, bloquear, cerrar sesion)
  LockScreen.qml / LockView.qml / ShapeGlyph.qml   bloqueo propio (contraseña como figuras animadas)
  lock-test.qml                 instancia de prueba del bloqueo (scripts/lock-test.sh)
  ClipboardPanel.qml            historial del portapapeles (cliphist): panel grande con busqueda, imagenes y borrado
  MediaPanel.qml / MediaState.qml   reproductor multimedia (MPRIS): panel con carátula, progreso y controles
  Controls.qml                  panel desplegable: volumen + salida, brillo, bateria + perfil de energia
  Toasts.qml / Toast.qml        notificaciones: tarjetas de vidrio arriba a la derecha, con rebote
  Dismiss.qml                   capa transparente: click fuera del notch cierra el menu abierto
  Slider.qml                    slider reutilizable (perilla con rebote)
  Brightness.qml                brillo via brightnessctl (con throttle)
  NiriState.qml                 workspaces y ventana enfocada vía `niri msg --json`
  Theme.qml                     colores, fuentes, tiempos de animación
scripts/                        pasos del instalador
docs/                           notas
```

## Atajos clave

| Tecla | Acción |
|-------|--------|
| `Mod+D` | abrir/cerrar el launcher de la píldora |
| `Mod+T` | terminal (alacritty) |
| hover en el notch | se expande: título, volumen, luz y batería |
| click en vol / luz / bat | abre el panel de controles (se cierra al sacar el ratón o con `Esc`) |
| click en el notch | launcher, con botones de energía abajo |
| `Mod+Shift+E` / `Ctrl+Alt+Del` | menú de apagado (← → mover, Enter elegir, Esc cerrar, letras L S R P E) |
| `Mod+M` | reproductor multimedia (maximizar a los bordes pasa a `Mod+Alt+M`) |
| `Mod+V` | portapapeles (como Win+V); la ventana flotante pasa a `Mod+Alt+V` |
| `Esc` | cierra cualquier menú del notch (launcher, portapapeles, multimedia, controles, apagado) |
| click fuera del notch | cierra el launcher, el panel de controles o el menú de apagado |
| scroll sobre el notch | volumen |
| teclas de brillo | suben/bajan brillo y muestran el HUD (van por `qs ipc call brightness up\|down`) |
| `Mod+Shift+/` | lista de atajos de niri |

Reiniciar, apagar y cerrar sesión piden confirmación: segundo click o segundo Enter dentro de 3 s.

(`Mod` = Super en una sesión real, Alt si niri corre anidado.)

## Actualizar niri

Cambia `NIRI_VERSION` en `scripts/lib.sh` y corre `./install.sh niri`.

## Pendiente

Ver [docs/roadmap.md](docs/roadmap.md).
