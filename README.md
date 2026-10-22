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
./install.sh niri link  # o pasos sueltos: packages | rust | niri | link | theme
```

| Paso | Qué hace |
|------|----------|
| `packages` | apt: dependencias de compilación, portales, audio, fuentes, y Quickshell desde `trixie-backports` |
| `rust` | rustup (el rustc de apt es viejo para niri) |
| `niri` | compila niri y xwayland-satellite (versiones fijadas en `scripts/lib.sh`), los instala en `/usr/local` y registra la sesión en GDM |
| `link` | enlaza `config/*` en `~/.config` (respalda lo que haya) y oculta el agente polkit de mate |
| `theme` | tema oscuro coherente: iconos Papirus-Dark, cursor y Qt siguiendo a GTK (`gsettings`) |

Después: cerrar sesión → engranaje de GDM → **niri**.

## Estructura

```
config/niri/config.kdl          compositor: layout, binds, blur, reglas de ventana
config/quickshell/pill/         la píldora (QML)
  shell.qml                     entrada: notificaciones, IPC, modo actual
  Pill.qml                      el notch: ventana, animaciones, icono de app activa, OSD, estado
  Wallpaper.qml                 fondo de pantalla (capa Background; necesario para el blur)
  Backdrop.qml                  mismo fondo, desenfocado, para el overview (Mod+O)
  Launcher.qml                  buscador de apps (con alias en espanol), apps fijadas / todas A-Z + fila de energia
  PinnedApps.qml                apps fijadas del launcher (~/.local/state/pill/pinned-apps)
  PowerMenu.qml / PowerButton.qml / PowerActions.qml   menu de apagado (apagar, reiniciar, suspender, bloquear, cerrar sesion)
  LockScreen.qml / LockView.qml / ShapeGlyph.qml   bloqueo propio (contraseña como figuras animadas)
  lock-test.qml                 instancia de prueba del bloqueo (scripts/lock-test.sh)
  ClipboardPanel.qml            historial del portapapeles (cliphist): panel grande con busqueda, imagenes y borrado
  MediaPanel.qml / MediaState.qml   reproductor multimedia (MPRIS): panel con carátula, progreso y controles
  BluetoothAudio.qml / bt-profile.py   al conectar audifonos: salida de audio a ellos + mejor perfil A2DP
  StatusBar.qml                 barra derecha: bandeja, boton de ajustes rapidos y boton campana + reloj
  QuickPanel.qml                panel unificado: inicio (bateria, volumen, brillo, tiles) y paginas de detalle
  NetworkState.qml / NetworkPage.qml / VpnPage.qml   Wi-Fi, Ethernet y VPN via nmcli / tailscale (docs/network.md)
  Idle.qml / BatteryAlerts.qml / PolkitDialog.qml   inactividad y suspension, avisos de bateria baja y agente polkit (docs/power.md)
  NightLight.qml / NightLightPage.qml   luz nocturna (wlsunset) con modos, intensidad y horario
  Field.qml / Btn.qml           campo de texto y boton de los menus
  ScreenCapture.qml / CapturePage.qml   capturas (niri) y grabacion (wf-recorder) con selector (docs/capture-emoji.md)
  EmojiPanel.qml / EmojiData.qml / emoji.json   selector de emoji en el notch con busqueda en espanol e ingles
  WallpaperPanel.qml            selector de fondos con miniaturas (Mod+Shift+W)
  wallpaper-palette.py          saca el acento y el tinte del vidrio del fondo de pantalla (paleta dinamica)
  HoverRow.qml                  fila de lista con resaltado, reutilizada por los menus
  AudioStreams.qml / AppMixer.qml / MicControl.qml   mezclador: volumen por app, microfono y "microfono en uso"
  NotificationCenter.qml / NotificationsPopover.qml   historial de notificaciones y No molestar
  DatePopover.qml               menu del reloj: calendario + notificaciones
  TrayMenuPopover.qml           menu de un icono de la bandeja del sistema
  CavaState.qml / cava.conf     barras de audio del notch (espectro real con cava, simulado sin el)
  PopoverHost.qml               tarjeta de vidrio que se abre bajo la barra con el menu pulsado
  VolumePopover.qml / BluetoothPopover.qml / BatteryPopover.qml   paginas Sonido, Bluetooth y Bateria del panel
  Toasts.qml / Toast.qml        notificaciones: tarjetas de vidrio arriba a la derecha, con rebote
  Dismiss.qml                   capa transparente: click fuera del notch cierra el menu abierto
  Slider.qml                    slider reutilizable (perilla con rebote)
  Brightness.qml                brillo via brightnessctl (con throttle)
  NiriState.qml                 workspaces y ventana enfocada vía `niri msg --json`
  Theme.qml                     colores, fuentes, tiempos de animación
scripts/                        pasos del instalador (y gen-emoji.py, que regenera emoji.json)
docs/                           notas
```

## Atajos clave

| Tecla | Acción |
|-------|--------|
| `Mod+D` | abrir/cerrar el launcher de la píldora |
| `Mod+T` | terminal (alacritty) |
| hover en el notch | se expande: título, volumen, luz y batería |
| click en un icono de la barra derecha | abre su menú (Bluetooth, volumen+brillo, batería, reloj); con uno abierto, otro icono cambia directo |
| click en el notch | launcher, con botones de energía abajo |
| `Mod+Shift+E` / `Ctrl+Alt+Del` | menú de apagado (← → mover, Enter elegir, Esc cerrar, letras L S R P E) |
| `Mod+M` | reproductor multimedia (maximizar a los bordes pasa a `Mod+Alt+M`) |
| `Mod+V` | portapapeles (como Win+V); la ventana flotante pasa a `Mod+Alt+V` |
| `Mod+;` | selector de emoji |
| `Mod+Shift+S` | panel de captura y grabación de pantalla |
| `Mod+Shift+W` | selector de fondos de pantalla |
| `Esc` | cierra cualquier menú del notch (launcher, portapapeles, multimedia, controles, apagado) |
| click fuera | cierra el launcher, el portapapeles, el reproductor, el menú de apagado o el menú de la barra derecha |
| scroll sobre el notch | volumen |
| teclas de brillo | suben/bajan brillo y muestran el HUD (van por `qs ipc call brightness up\|down`) |
| `Mod+Shift+/` | lista de atajos de niri |

Reiniciar, apagar y cerrar sesión piden confirmación: segundo click o segundo Enter dentro de 3 s.

(`Mod` = Super en una sesión real, Alt si niri corre anidado.)

## Actualizar niri

Cambia `NIRI_VERSION` en `scripts/lib.sh` y corre `./install.sh niri`.

## Pendiente

Ver [docs/roadmap.md](docs/roadmap.md).
