# Portapapeles

`Mod+V` (o el icono de portapapeles al pasar el ratón por el notch) abre el historial: un panel grande
(hasta ~55 % de la altura de la pantalla) que baja del notch con rebote.

| Acción | Cómo |
|---|---|
| Buscar | escribe |
| Mover | ↑ ↓ (o el ratón) |
| Copiar | Enter o click en la tarjeta (queda en el portapapeles; pega con Ctrl+V) |
| Borrar una entrada | Supr o la ✕ de la tarjeta |
| Borrar todo | "Borrar todo" (pide un segundo click) |
| Cerrar | Esc o click fuera |

## Cómo funciona

El historial lo guarda [cliphist](https://github.com/sentriz/cliphist), alimentado por dos procesos de
`wl-paste --watch` que niri lanza al iniciar (`spawn-sh-at-startup` en `config.kdl`): uno para texto y otro
para imágenes. La base está en `~/.cache/cliphist/db`. Las miniaturas de imágenes se decodifican bajo
demanda a `$XDG_RUNTIME_DIR/pill-clip/` (se borra al cerrar sesión).

## Privacidad

cliphist guarda **todo lo que copias**, incluidas contraseñas copiadas desde un gestor. Mantén el historial
corto (por defecto 750 entradas), usa "Borrar todo" cuando quieras, y si usas un gestor de contraseñas
revisa que marque sus copias como sensibles (muchos lo hacen con el tipo MIME
`x-kde-passwordManagerHint`, que cliphist respeta con `wl-paste --watch` en versiones recientes; la 0.5.0
de Debian 13 **no**: considera el riesgo).
