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

cliphist guarda **todo lo que copias**, y eso incluye contraseñas copiadas desde un gestor. No he
comprobado si la versión de Debian 13 (0.5.0) ignora las copias que los gestores marcan como sensibles,
así que asume que **no** lo hace: usa "Borrar todo" después de copiar secretos, o borra la entrada con
Supr. El historial queda en `~/.cache/cliphist/db` (sin cifrar), con un máximo de 750 entradas.
