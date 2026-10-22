# Inactividad, suspensión, polkit y batería

## Inactividad (`Idle.qml`)
Sustituye a swayidle. Con los tiempos de `Theme.idle*Seconds` (0 desactiva el paso):

| Paso | Por defecto | Qué hace |
|---|---|---|
| Atenuar | 4 min | baja el brillo al 15 % (lo devuelve al mover algo) |
| Bloquear | 5 min | abre el bloqueo propio |
| Apagar pantalla | 5 min 30 s | `niri msg action power-off-monitors` (se enciende al mover el ratón) |
| Suspender | 15 min | `systemctl suspend`, **solo con batería** (enchufado nunca suspende solo) |

- Usa `ext-idle-notify` y **respeta a las apps que inhiben la inactividad** (video, presentaciones, y
  algunas apps de escritorio mientras trabajan). Si nunca se atenúa/bloquea, alguna app está inhibiendo.
- **No suspender** (tile del panel de ajustes rápidos o `qs -c pill ipc call idle caffeine`) apaga todos
  los pasos; sale una taza en la barra mientras está activo.
- **Bloquear antes de suspender** (`Theme.lockBeforeSleep`): sea por la tapa, el botón, el menú de apagado o
  la inactividad, bloquea *antes* de dormir. Usa un inhibidor de sueño `delay` de systemd
  (`systemd-inhibit --list` lo muestra como `pill`) y la señal `PrepareForSleep` de logind. Para que la tapa
  suspenda, logind ya lo hace por defecto (`HandleLidSwitch=suspend`).
- Estado: `qs -c pill ipc call idle status`.

## Agente polkit (`PolkitDialog.qml`)
Cuando algo pide permisos de administrador (`pkexec`, montar discos, ajustes del sistema…) sale una tarjeta
de vidrio con el mensaje y el campo de contraseña. Esc o *Cancelar* rechazan.
- Solo puede haber **un agente por sesión**. `scripts/04-link.sh` crea
  `~/.config/autostart/polkit-mate-authentication-agent-1.desktop` con `Hidden=true` para que no arranque
  mate-polkit en niri.
- **Volver a mate-polkit:** borra ese archivo, pon `Theme.polkitAgent: false` y reinicia la sesión.
- Probar: `pkexec true` y `qs -c pill ipc call polkit status` / `polkit cancel`.

## Batería baja (`BatteryAlerts.qml`)
Avisa una vez por descarga al 20 %, 10 % y 5 % (`Theme.batteryWarnLevels`) con una notificación normal; los
dos últimos niveles son **críticos** y atraviesan *No molestar*. Se rearma al cargar. La acción final
(apagar o suspender al 2 %) la hace UPower (`PercentageAction` en `/etc/UPower/UPower.conf`).
Probar: `qs -c pill ipc call battery simulate 18` (y `simulate -1` para volver a la batería real).
