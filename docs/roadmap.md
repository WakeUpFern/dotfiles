# Roadmap

- [ ] Primer arranque en niri y ajuste de la píldora (el QML no se ha podido probar fuera de niri)
- [ ] Fondo de pantalla (Quickshell `WlrLayershell` en capa Background)
- [ ] Bandeja del sistema (`Quickshell.Services.SystemTray`) dentro de la píldora
- [x] Panel de controles: volumen, salida de audio, brillo, bateria y perfil de energia
- [ ] Red y bluetooth dentro del panel de controles
- [x] Notificaciones emergentes (tarjetas de vidrio arriba a la derecha)
- [ ] Centro de notificaciones con historial, acciones y "no molestar"
- [x] Menu de apagado (usa swaylock para bloquear)
- [ ] Bloqueo de pantalla propio (`Quickshell.Wayland.WlSessionLock`) para reemplazar swaylock
- [ ] Agente polkit (módulo `Quickshell.Services.Polkit`)
- [x] Portapapeles con historial (cliphist) en el notch
- [x] Reproductor multimedia (MPRIS) en el notch
- [ ] Idle/suspensión (`swayidle` o `Quickshell.Wayland.IdleMonitor`)
- [ ] Captura de pantalla integrada (niri ya trae `screenshot`)
- [ ] Tema de GTK/Qt coherente (Adwaita-dark + Papirus) y cursor
- [ ] Paleta dinámica desde el wallpaper (opcional)
