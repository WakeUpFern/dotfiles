# Bluetooth

Menú del icono de Bluetooth en la **barra derecha** (azul si hay algo conectado, gris si está apagado).

| Elemento | Qué hace |
|---|---|
| Interruptor | enciende / apaga el adaptador |
| **Buscar** | busca dispositivos nuevos (etiqueta "Nuevo"); se apaga solo a los 30 s o al cerrar el panel |
| Fila de un dispositivo | click = conectar; si está conectado, click = desconectar; si es nuevo, lo empareja, lo marca de confianza y lo conecta |
| Resumen | nombres de lo conectado con su batería (si el dispositivo la reporta) |
| **Calidad del audio** | perfil activo de unos audífonos conectados; click para cambiarlo |

Se muestran como máximo 4 dispositivos: conectados, emparejados y, mientras buscas, los nuevos **con nombre**.
BlueZ usa la dirección MAC como nombre de los dispositivos anónimos (balizas, mandos, etc.); esos se ocultan.

## Al conectar unos audífonos (`BluetoothAudio.qml`)

1. La **salida de audio** pasa a los audífonos. (PipeWire/WirePlumber no lo hacía porque, si ya hay una
   salida elegida a mano, la conserva.) Al desconectarlos, WirePlumber vuelve solo a la anterior.
2. Se elige el **mejor perfil de música** que ofrezca el dispositivo: A2DP **SBC-XQ** antes que A2DP SBC.
   Solo si están en música: si una app de llamadas ya los puso en "Llamadas", no se toca.

Se desactivan con `btAutoSwitchOutput` y `btPreferHighQuality` en `Theme.qml`. Solo actúa cuando aparece una
salida Bluetooth **nueva** (no al arrancar Quickshell), así tu elección manual no se pisa en cada recarga.

## "Handsfree" y "Headset" (el doble dispositivo de GNOME)

Son perfiles distintos del *mismo* dispositivo; PipeWire solo muestra la salida del perfil activo:

| Perfil | Para qué | Calidad |
|---|---|---|
| **Música** (A2DP: SBC, SBC-XQ) | escuchar | alta, **sin micrófono** del auricular |
| **Llamadas** (HSP/HFP: CVSD, mSBC, LC3-SWB) | hablar | baja, con micrófono |

En Debian 13 no hay AAC/LDAC/aptX en los paquetes de PipeWire, así que lo mejor disponible es SBC-XQ.
El panel muestra los perfiles reales del dispositivo (`bt-profile.py` los lee con `pw-cli` y cambia con `wpctl set-profile`).

**Ojo:** por defecto WirePlumber baja solo a "Llamadas" cuando una app abre el micrófono (Meet, Discord…) y el
sonido empeora hasta que cierre. Es el ajuste `bluetooth.autoswitch-to-headset-profile`. Para mantener siempre
"Música" (y usar el micrófono del portátil en las llamadas), crea
`~/.config/wireplumber/wireplumber.conf.d/51-bluetooth.conf` con:

```
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}
```

y reinicia WirePlumber (`systemctl --user restart wireplumber`). No está activado por defecto.

Usa `Quickshell.Bluetooth` (BlueZ por D-Bus) y `Quickshell.Services.Pipewire`.

## Sin desconexiones por accidente

Un clic en un dispositivo **conectado** abre sus detalles (batería) y ahí está *Desconectar*. El tile de
Bluetooth del panel, estando encendido, abre la página en vez de apagarlo; se apaga con el interruptor de
la página.
