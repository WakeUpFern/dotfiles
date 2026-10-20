#!/usr/bin/env python3
"""Perfiles de un dispositivo Bluetooth de audio en PipeWire (lee y cambia).

  bt-profile.py list NOMBRE           -> JSON con el id del dispositivo, el perfil activo y los posibles
  bt-profile.py set  NOMBRE INDICE    -> cambia de perfil (wpctl set-profile)
  bt-profile.py best NOMBRE           -> pasa al mejor perfil A2DP disponible (SBC-XQ > SBC) si el
                                         dispositivo esta en A2DP; si esta en llamadas (HSP/HFP) no toca nada

NOMBRE es el nombre del dispositivo tal como lo muestra wpctl (p. ej. "Buds4 Pro de Fernando").
"""
import json, re, subprocess, sys


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def device_id(name):
    # Lineas de `wpctl status`:   │      71. Buds4 Pro de Fernando     [bluez5]
    for line in run("wpctl", "status").splitlines():
        m = re.search(r"(\d+)\.\s+(.+?)\s+\[bluez5\]", line)
        if m and m.group(2).strip() == name:
            return int(m.group(1))
    return None


def parse(text):
    """Convierte la salida de `pw-cli enum-params` en una lista de perfiles."""
    out = []
    for block in re.split(r"\n\s*Object:", "\n" + text):
        idx = re.search(r"Profile:index \(1\).*\n\s+Int (\d+)", block)
        if not idx:
            continue
        name = re.search(r':name \(2\).*\n\s+String "([^"]*)"', block)
        desc = re.search(r':description \(3\).*\n\s+String "([^"]*)"', block)
        avail = re.search(r":available \(5\).*\n\s+Id (\d+)", block)
        out.append({
            "index": int(idx.group(1)),
            "name": name.group(1) if name else "",
            "description": desc.group(1) if desc else "",
            "available": (int(avail.group(1)) != 1) if avail else True,   # 1 = "no"
        })
    return out


def info(name):
    dev = device_id(name)
    if dev is None:
        return {"device": None, "active": None, "profiles": []}
    profiles = parse(run("pw-cli", "enum-params", str(dev), "EnumProfile"))
    active = parse(run("pw-cli", "enum-params", str(dev), "Profile"))
    return {"device": dev, "active": active[0]["index"] if active else None, "profiles": profiles}


def rank(p):
    d = p["description"]
    if "A2DP" in d and "SBC-XQ" in d:
        return 3
    if "A2DP" in d:
        return 2
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__); return 2
    cmd, name = sys.argv[1], sys.argv[2]
    i = info(name)
    if cmd == "list":
        print(json.dumps(i)); return 0
    if i["device"] is None:
        print("dispositivo no encontrado", file=sys.stderr); return 1
    if cmd == "set":
        subprocess.run(["wpctl", "set-profile", str(i["device"]), sys.argv[3]]); return 0
    if cmd == "best":
        cur = next((p for p in i["profiles"] if p["index"] == i["active"]), None)
        if cur is None or rank(cur) == 0:      # llamadas (HFP) u apagado: no se toca
            print("sin cambios (no esta en A2DP)"); return 0
        best = max((p for p in i["profiles"] if p["available"]), key=rank)
        if rank(best) > rank(cur):
            subprocess.run(["wpctl", "set-profile", str(i["device"]), str(best["index"])])
            print("cambiado a", best["description"])
        else:
            print("ya esta en el mejor A2DP:", cur["description"])
        return 0
    print(__doc__); return 2


sys.exit(main())
