# Monitor del sistema

Arriba a la **izquierda** (la barra derecha ya tiene los ajustes y el reloj) hay un monitor discreto, sin
fondo y con la misma sombra suave que la barra derecha:

```
CPU 13%   RAM 45%   🌡 44°   ↓ 187K  ↑ 5K
```

Cada valor tiene **ancho fijo** (no baila al cambiar) y pasa a **naranja / rojo** cerca del límite:
CPU 70 / 90 %, RAM 80 / 92 %, temperatura 75 / 88 °C. Las velocidades de red salen apagadas mientras no hay
tráfico. En pantalla completa la barra se esconde hacia arriba, como el notch.

**Clic** (o `Ctrl+Shift+Escape`, o `qs -c pill ipc call popover toggle system`) abre el detalle; `Esc` o un
clic fuera lo cierra. Es exclusivo con los menús de la derecha: abrir uno cierra el otro.

## Qué muestra el detalle

| Sección | Contenido |
|---|---|
| **CPU** | porcentaje total y frecuencia media, gráfica del último minuto, una barra por hilo y la carga (1/5/15 min) |
| **Memoria** | usada / total (la misma cuenta que `free`: total menos disponible), gráfica y swap |
| **Temperatura** | CPU (`k10temp`/`coretemp`) y, si existen, GPU, disco NVMe y ventilador |
| **Red** | bajada y subida (naranja) con la misma escala; suma las interfaces físicas, sin `lo`, Docker ni Tailscale para no contar el tráfico dos veces |
| **Disco** | uso de `/` y lectura/escritura por segundo del disco |
| **Consumo (batería)** | vatios que salen de la batería ahora mismo; solo mientras se descarga |
| **Más CPU / Más memoria** | los 5 programas que más gastan, **agrupados por nombre** (Chrome suma todos sus procesos) |

## Qué cuesta

Todo sale de `/proc` y `/sys`, sin lanzar procesos en reposo:

- **Menú cerrado:** unos pocos archivos cada 2 s (~1 % de CPU de Quickshell en reposo, ~60 despertares/s,
  menos que antes de añadirlo).
- **Menú abierto:** muestrea cada segundo, lee discos y ejecuta `top` (2 pasadas de 1 s) cada 3 s para la lista
  de procesos. Al cerrarlo, todo eso se detiene.

## Ajustes

`Theme.sysmonShow` (`Theme.qml`) elige qué valores salen en la barra: `cpu`, `ram`, `temp`, `net`.

## Cómo funciona

- `SystemStats.qml` (singleton): lee `/proc/stat`, `meminfo`, `net/dev`, `diskstats`, `loadavg`, `cpuinfo` y
  los sensores de `/sys/class/hwmon` (se buscan **por nombre**, porque el número `hwmonN` cambia entre
  arranques) con `FileView`, y calcula porcentajes y velocidades entre dos lecturas.
- `SysBar.qml` (barra), `SysPopover.qml` (tarjeta de vidrio con el mismo resorte que `PopoverHost`),
  `SysMonitor.qml` (contenido) y `Spark.qml` (gráfica de línea con relleno).
- El detalle va con el blur en vivo como el resto (`namespace` `pill-popover-left`, regla `^pill` de niri).

## Límites

- La temperatura de la barra es la de la CPU; no hay sensor de GPU dedicada (esta máquina es una APU).
- Si el ventilador no tiene sensor legible o está parado muestra `0 rpm`.
- El consumo en vatios es el de la **batería**, no el de la pared; con el cargador conectado no se muestra.
