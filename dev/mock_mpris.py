#!/usr/bin/env python3
"""Reproductor MPRIS falso para probar el panel multimedia (no suena nada).

Uso:  python3 dev/mock_mpris.py        (Ctrl+C para salir)
Crea 3 pistas con caratula generada y anota cada comando recibido en $MOCK_DIR/calls.log
(por defecto /tmp/pill-mock). Aparece como "Reproductor de prueba" en el panel multimedia;
el selector (o qs -c pill ipc call media select prueba) permite apuntar los controles a el
sin tocar tus reproductores reales.
"""
import gi, time, zlib, struct, sys, os
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

HERE = os.environ.get("MOCK_DIR", "/tmp/pill-mock")
os.makedirs(HERE, exist_ok=True)
LOG = open(os.path.join(HERE, "calls.log"), "a", buffering=1)

def png(path, c1, c2, n=300):
    rows = b""
    for y in range(n):
        row = b"\x00"
        for x in range(n):
            t = (x + y) / (2 * n)
            row += bytes(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
        rows += row
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)

TRACKS = [
    ("Noche en Niri", "Los Compositores", "Rice Sessions", 214, (40, 90, 200), (200, 60, 160)),
    ("Quickshell Blues", "Pill & The Notches", "Dotfiles Vol. 1", 187, (230, 150, 40), (200, 40, 60)),
    ("Una canción con un título bastante largo para probar el recorte", "Artista con Nombre Muy Largo Feat. Otro", "Álbum", 301, (30, 160, 120), (20, 40, 90)),
]
for i, t in enumerate(TRACKS):
    png(os.path.join(HERE, f"art{i}.png"), t[4], t[5])

XML = """
<node>
 <interface name="org.mpris.MediaPlayer2">
  <method name="Raise"/><method name="Quit"/>
  <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
  <property name="DesktopEntry" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
 </interface>
 <interface name="org.mpris.MediaPlayer2.Player">
  <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/><method name="Stop"/><method name="Play"/>
  <method name="Seek"><arg type="x" direction="in"/></method>
  <method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
  <method name="OpenUri"><arg type="s" direction="in"/></method>
  <signal name="Seeked"><arg type="x"/></signal>
  <property name="PlaybackStatus" type="s" access="read"/>
  <property name="LoopStatus" type="s" access="readwrite"/>
  <property name="Rate" type="d" access="readwrite"/>
  <property name="Shuffle" type="b" access="readwrite"/>
  <property name="Metadata" type="a{sv}" access="read"/>
  <property name="Volume" type="d" access="readwrite"/>
  <property name="Position" type="x" access="read"/>
  <property name="MinimumRate" type="d" access="read"/><property name="MaximumRate" type="d" access="read"/>
  <property name="CanGoNext" type="b" access="read"/><property name="CanGoPrevious" type="b" access="read"/>
  <property name="CanPlay" type="b" access="read"/><property name="CanPause" type="b" access="read"/>
  <property name="CanSeek" type="b" access="read"/><property name="CanControl" type="b" access="read"/>
 </interface>
</node>"""

class S:  # estado
    idx = 0; status = "Playing"; base = 0.0; t0 = time.time(); vol = 0.7; shuffle = False; loop = "None"

def pos_us():
    if S.status == "Playing": return int((S.base + time.time() - S.t0) * 1e6)
    return int(S.base * 1e6)

def meta():
    t = TRACKS[S.idx]
    return GLib.Variant("a{sv}", {
        "mpris:trackid": GLib.Variant("o", f"/mock/track/{S.idx}"),
        "mpris:length": GLib.Variant("x", t[3] * 1000000),
        "mpris:artUrl": GLib.Variant("s", "file://" + os.path.join(HERE, f"art{S.idx}.png")),
        "xesam:title": GLib.Variant("s", t[0]),
        "xesam:artist": GLib.Variant("as", [t[1]]),
        "xesam:album": GLib.Variant("s", t[2]),
    })

conn = None
def changed(props):
    d = {}
    for p in props:
        d[p] = get_prop(None, None, None, "org.mpris.MediaPlayer2.Player", p)
    conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
        GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", d, [])))

def goto(i):
    S.idx = i % len(TRACKS); S.base = 0.0; S.t0 = time.time()
    changed(["Metadata", "PlaybackStatus"])

def get_prop(c, sender, path, iface, name):
    P = {
      "CanQuit": ("b", False), "CanRaise": ("b", False), "HasTrackList": ("b", False), "Identity": ("s", "Reproductor de prueba"),
      "DesktopEntry": ("s", "pilltest"), "SupportedUriSchemes": ("as", ["file"]), "SupportedMimeTypes": ("as", ["audio/mpeg"]),
      "PlaybackStatus": ("s", S.status), "LoopStatus": ("s", S.loop), "Rate": ("d", 1.0), "Shuffle": ("b", S.shuffle),
      "Volume": ("d", S.vol), "Position": ("x", pos_us()), "MinimumRate": ("d", 1.0), "MaximumRate": ("d", 1.0),
      "CanGoNext": ("b", True), "CanGoPrevious": ("b", True), "CanPlay": ("b", True), "CanPause": ("b", True),
      "CanSeek": ("b", True), "CanControl": ("b", True),
    }
    if name == "Metadata": return meta()
    t, v = P[name]; return GLib.Variant(t, v)

def set_prop(c, sender, path, iface, name, value):
    LOG.write(f"SET {name}={value.unpack()}\n")
    if name == "Volume": S.vol = value.get_double()
    elif name == "Shuffle": S.shuffle = value.get_boolean()
    elif name == "LoopStatus": S.loop = value.get_string()
    changed([name]); return True

def call(c, sender, path, iface, method, params, inv):
    args = params.unpack()
    LOG.write(f"CALL {method} {args}\n")
    if method == "Next": goto(S.idx + 1)
    elif method == "Previous":
        if pos_us() > 3e6: S.base = 0.0; S.t0 = time.time(); c.emit_signal(None, path, "org.mpris.MediaPlayer2.Player", "Seeked", GLib.Variant("(x)", (0,)))
        else: goto(S.idx - 1)
    elif method in ("PlayPause", "Play", "Pause", "Stop"):
        cur = pos_us() / 1e6
        new = {"PlayPause": "Paused" if S.status == "Playing" else "Playing", "Play": "Playing", "Pause": "Paused", "Stop": "Stopped"}[method]
        S.base = cur; S.t0 = time.time(); S.status = new; changed(["PlaybackStatus"])
    elif method == "Seek":
        S.base = max(0, pos_us() / 1e6 + args[0] / 1e6); S.t0 = time.time()
        c.emit_signal(None, path, "org.mpris.MediaPlayer2.Player", "Seeked", GLib.Variant("(x)", (int(S.base * 1e6),)))
    elif method == "SetPosition":
        S.base = args[1] / 1e6; S.t0 = time.time()
        c.emit_signal(None, path, "org.mpris.MediaPlayer2.Player", "Seeked", GLib.Variant("(x)", (args[1],)))
    inv.return_value(None)

def on_bus(c, name):
    global conn; conn = c
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    for i in node.interfaces:
        c.register_object("/org/mpris/MediaPlayer2", i, call, get_prop, set_prop)

Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.pilltest", Gio.BusNameOwnerFlags.NONE, on_bus, None, None)
LOG.write("START\n")
GLib.MainLoop().run()
