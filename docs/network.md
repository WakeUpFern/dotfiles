# Red: Wi-Fi, Ethernet y VPN

Todo va por `nmcli` (NetworkManager) desde `NetworkState.qml`; el estado se refresca con `nmcli monitor`
(eventos) y un sondeo de 15 s de respaldo. La página **Red** y la de **VPN** del panel de ajustes rápidos lo usan.

## Wi-Fi
- Interruptor, **Buscar** (rescan) y lista por intensidad; la conectada arriba.
- **Red guardada o abierta:** un clic conecta. **Olvidar** aparece al pasar el ratón por una guardada que no
  esté en uso.
- **Red conectada:** un clic solo abre sus **detalles** (señal, seguridad, IP) y ahí están *Desconectar* y
  *Olvidar red*; así un clic por error no te deja sin conexión. Lo mismo en Ethernet y en las VPN (se
  apagan con su interruptor, no con el clic en la fila). Los tiles de Red y VPN, estando activos, abren su
  página en vez de apagarse.
- **Red nueva con contraseña:** el clic despliega un campo; Enter o *Conectar*. Si falla (contraseña mala) se
  avisa y se borra el perfil a medias.
- **Red oculta:** "Conectar a una red oculta…" pide el nombre (SSID) y la contraseña (vacía = abierta) y
  conecta con `nmcli device wifi connect <ssid> password <pw> hidden yes`. Queda guardada como cualquier otra.
- **Redes empresariales (WPA2 802.1X):** no se configuran aquí; úsalas con `nm-connection-editor` y una vez
  guardadas el clic las conecta.
- La contraseña viaja como argumento de `nmcli` (visible un instante para tu propio usuario con `ps`).

## Ethernet
Cada interfaz cableada aparece en "Cableado": *Conectado*, *Desconectado* (clic conecta) o *Sin cable*. Si
ninguna tiene cable se resume en una sola línea. Con cable conectado el icono de la barra cambia a Ethernet
y el tile dice "Ethernet".

## VPN
- **NetworkManager:** perfiles de tipo `vpn` (OpenVPN, etc.) y `wireguard`; interruptor por perfil
  (`nmcli connection up|down id <nombre>`). Importar uno:
  `nmcli connection import type wireguard file ~/mi.conf` (OpenVPN: instala `network-manager-openvpn`).
- **Tailscale:** si está instalado aparece como una VPN más (`tailscale up|down`). Para encenderlo sin sudo,
  una sola vez: `sudo tailscale set --operator=$USER`.
- El tile VPN solo aparece si hay alguna; con una sola VPN un clic la enciende o apaga, con varias abre la página.
  El candado azul de la barra indica que hay una activa.

## Punto de acceso (compartir la conexión)
En la página Red, "Compartir conexión (punto de acceso)" pide nombre y contraseña (8 a 63 caracteres; la
primera vez propone `Pill-<equipo>` y una contraseña aleatoria) y crea el perfil `PillHotspot`
(`nmcli connection add type wifi … 802-11-wireless.mode ap ipv4.method shared`, banda 2,4 GHz, WPA2).
- **Ojo:** la tarjeta Wi-Fi pasa a ser el punto de acceso, así que **dejas de estar conectado a tu Wi-Fi**
  mientras esté activo (la página lo avisa y no lo activa con un clic suelto: hay que pulsar *Activar*).
  Con Ethernet conectado sigues con internet y lo compartes.
- Activo, la página muestra el nombre y la contraseña y el botón *Detener*.
- Necesita `dnsmasq-base` (viene con NetworkManager) para repartir direcciones.

## Modo avión
Tile del panel: apaga Wi-Fi y Bluetooth (sin `rfkill`: `nmcli radio wifi off` y BlueZ). **Hay que pulsarlo
dos veces** (el primer clic solo lo arma, 3 s) porque corta la red; salir del modo avión es un clic.
