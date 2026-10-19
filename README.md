# dotfiles - niri + Quickshell en Debian 13

Rice para Debian 13 (trixie). Un solo compositor (**niri**) y un solo shell
(**Quickshell**): un *notch* pegado al borde superior (estilo Mac) que hace de barra,
launcher, centro de notificaciones, HUD de volumen y panel de estado, con animaciones de resorte. Estética inicial: vidrio esmerilado (blur nativo de niri).

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
  Launcher.qml                  buscador de apps
  Controls.qml                  panel desplegable: volumen + salida, brillo, bateria + perfil de energia
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
| click en otra zona del notch | launcher |
| scroll sobre el notch | volumen |
| teclas de brillo | suben/bajan brillo y muestran el HUD (van por `qs ipc call brightness up\|down`) |
| `Mod+Shift+/` | lista de atajos de niri |

(`Mod` = Super en una sesión real, Alt si niri corre anidado.)

## Actualizar niri

Cambia `NIRI_VERSION` en `scripts/lib.sh` y corre `./install.sh niri`.

## Pendiente

Ver [docs/roadmap.md](docs/roadmap.md).
