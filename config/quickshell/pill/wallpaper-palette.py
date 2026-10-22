#!/usr/bin/env python3
"""Saca la paleta del fondo de pantalla: el matiz dominante (ponderado por saturacion y brillo) y de el
un color de acento claro, una base oscura tintada para el vidrio y el nombre de acento de GNOME mas cercano.

Uso:  python3 -I wallpaper-palette.py <imagen>      (necesita python3-gi y GdkPixbuf)
Salida (una linea JSON): {"accent":"#8ab4ff","glass":"#10121a","gtk":"blue","hue":220,"vivid":0.42}
"""
import colorsys, json, math, sys
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf

DEFAULT = {"accent": "#8ab4ff", "glass": "#121219", "gtk": "blue", "hue": 220, "vivid": 0.0}
BINS = 36

def hexcolor(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))

def gtk_accent(hue, vivid):
    if vivid < 0.015:
        return "slate"
    for lo, hi, name in ((15, 45, "orange"), (45, 70, "yellow"), (70, 165, "green"), (165, 200, "teal"),
                         (200, 255, "blue"), (255, 300, "purple"), (300, 350, "pink")):
        if lo <= hue < hi:
            return name
    return "red"

def main(path):
    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 96, 96, True)
    px, n, stride = pb.get_pixels(), pb.get_n_channels(), pb.get_rowstride()
    weight = [0.0] * BINS
    sx = [0.0] * BINS          # suma de cos/sin del matiz de cada bin (media circular)
    sy = [0.0] * BINS
    total = count = 0
    for y in range(pb.get_height()):
        row = y * stride
        for x in range(pb.get_width()):
            i = row + x * n
            r, g, b = px[i] / 255, px[i + 1] / 255, px[i + 2] / 255
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            count += 1
            if s < 0.18 or v < 0.2:
                continue                                   # grises y negros no dan matiz
            w = (s ** 1.5) * v
            k = int(h * BINS) % BINS
            weight[k] += w
            sx[k] += w * math.cos(h * 2 * math.pi)
            sy[k] += w * math.sin(h * 2 * math.pi)
            total += w
    vivid = total / count if count else 0.0
    if total <= 0 or vivid < 0.008:
        print(json.dumps(DEFAULT)); return
    # El mejor bin junto a sus vecinos (evita que un matiz partido en dos gane por azar).
    best = max(range(BINS), key=lambda k: weight[k - 1] + weight[k] + weight[(k + 1) % BINS])
    idx = [(best - 1) % BINS, best, (best + 1) % BINS]
    cx, cy = sum(sx[k] for k in idx), sum(sy[k] for k in idx)
    hue = (math.atan2(cy, cx) / (2 * math.pi)) % 1.0
    out = {
        "accent": hexcolor(hue, 0.74, 0.70),
        "glass": hexcolor(hue, 0.075, 0.30),
        "gtk": gtk_accent(hue * 360, vivid),
        "hue": round(hue * 360),
        "vivid": round(vivid, 3),
    }
    print(json.dumps(out))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("uso: wallpaper-palette.py <imagen>")
    try:
        main(sys.argv[1])
    except Exception as e:                                  # imagen ilegible: se queda la paleta por defecto
        print(json.dumps(DEFAULT))
        print("wallpaper-palette:", e, file=sys.stderr)
