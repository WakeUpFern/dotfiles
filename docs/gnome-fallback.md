# GNOME como respaldo

Se conserva GNOME 48 (sesión Wayland oficial de Debian) aunque el rice esté completo:

- Si una actualización rompe niri o Quickshell, se entra a GNOME desde el engranaje de GDM.
- niri se instala en `/usr/local` y `/usr/share/wayland-sessions/niri.desktop`: no toca ningún paquete de GNOME.
- Se comparten servicios (PipeWire, NetworkManager, portales, gnome-keyring), así que no hay duplicados.

## Cambiar de sesión
Cerrar sesión → en la pantalla de contraseña, engranaje abajo a la derecha → **GNOME** o **niri**.

## Si niri no arranca
1. Entrar a GNOME o a una TTY (`Ctrl+Alt+F3`).
2. Ver el log: `journalctl --user -u niri -b`.
3. Validar la config: `niri validate -c ~/.config/niri/config.kdl`.
4. Restaurar un respaldo anterior desde `~/.config/dotfiles-backup/`.

## Quitar niri por completo
```bash
sudo rm /usr/local/bin/{niri,niri-session,xwayland-satellite} \
        /usr/share/wayland-sessions/niri.desktop \
        /usr/share/xdg-desktop-portal/niri-portals.conf \
        /etc/systemd/user/niri.service /etc/systemd/user/niri-shutdown.target
```
