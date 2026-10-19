# dotfiles - niri + Quickshell en Debian 13

Rice para Debian 13 (trixie). Un solo compositor (**niri**) y un solo shell
(**Quickshell**): una *píldora* flotante que hace de barra, launcher, centro de
notificaciones y panel de estado. Estética inicial: vidrio esmerilado (blur nativo de niri).

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
  Pill.qml                      ventana + animaciones + estado (workspaces, volumen, batería, reloj)
  Launcher.qml                  buscador de apps
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
| `Mod+Shift+/` | lista de atajos de niri |

(`Mod` = Super en una sesión real, Alt si niri corre anidado.)

## Actualizar niri

Cambia `NIRI_VERSION` en `scripts/lib.sh` y corre `./install.sh niri`.

## Pendiente

Ver [docs/roadmap.md](docs/roadmap.md).
