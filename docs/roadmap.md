# Roadmap

## Hecho
- [x] Fondo de pantalla (capa Background, necesario para el blur) y fondo desenfocado del overview
- [x] Barra derecha: bandeja del sistema, panel unificado de ajustes rápidos (Wi-Fi, Ethernet, VPN, Bluetooth,
  sonido, batería, brillo, No molestar, No suspender, Luz nocturna, Modo avión) y campana + reloj con calendario
- [x] Mezclador de audio por aplicación y micrófono, con aviso de "micrófono en uso"
- [x] Notificaciones emergentes, historial y No molestar
- [x] Launcher: apps fijadas, lista completa A-Z, búsqueda por descripción/categoría y alias en español
- [x] Menú de apagado, bloqueo de pantalla propio (`WlSessionLock`) e inactividad/suspensión con bloqueo antes de dormir
- [x] Agente polkit propio y avisos de batería baja
- [x] Portapapeles con historial, reproductor multimedia (MPRIS) y selector de emoji
- [x] Capturas, grabación de pantalla y punto de acceso Wi-Fi
- [x] Paleta dinámica desde el fondo, selector de fondos y tema GTK/Qt/cursor coherente

## Pendiente
- [ ] **Launcher como centro de acciones:** calculadora y conversión de unidades, búsqueda de archivos, atajos
  de búsqueda web (`g gatos`), ejecutar comandos (`>`) y recientes por uso
- [ ] **Notificaciones:** persistir el historial y "No molestar" entre reinicios, y botones de acción (responder,
  abrir…) dentro del historial
- [ ] **Audio:** mover una app a otra salida (hoy solo se ajusta su volumen) y audio en las grabaciones de pantalla
- [ ] **Indicadores:** distribución de teclado, Caps/Num Lock y cámara en uso
- [ ] **Volúmenes y USB:** aviso al conectar y expulsar desde el panel
- [ ] **Monitor del sistema:** CPU, RAM, temperatura y red (al pasar el ratón o como página del panel)
- [ ] **Ventanas:** lista de ventanas abiertas en el notch o un Alt+Tab propio
- [ ] **Estilo:** que el borde de las ventanas de niri siga el acento (niri no recarga colores en vivo)

## Por verificar en uso real (se probaron las piezas, no el flujo completo)
- [ ] Bloquear al cerrar la tapa y al suspender; apagar pantalla y suspender por inactividad
- [ ] Activar el punto de acceso y el modo avión (cortan la red)
- [ ] Elegir un emoji y que `wtype` lo escriba en la app; el selector de área de captura
- [ ] Apps Qt siguiendo el tema GTK tras volver a iniciar sesión
