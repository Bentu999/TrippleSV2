import json
import os
import struct

path = r"D:\zz Map New\Beispielkarten\1\The_Forge.sanmap"
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

print("TOP KEYS:", list(data.keys()))
print("fileVersion", data.get("fileVersion"), "mapVersion", data.get("mapVersion"))
print("size", data["width"], data["length"], data["height"], "hm", data["heightmapResolution"])
print("stratum count", len(data.get("stratumLayers", [])))
for i, s in enumerate(data.get("stratumLayers", [])):
    albedo = s.get("albedo", {}).get("path", "")
    print(f"  stratum[{i}] name={s.get('name')} albedo={albedo[:90]}")

print("areas", list(data.get("areas", {}).keys()))
for k, v in data.get("areas", {}).items():
    print(" ", k, v)

print("armies count", len(data.get("armies", {})))
if data.get("armies"):
    aid = next(iter(data["armies"]))
    print(" army sample", aid, json.dumps(data["armies"][aid])[:300])

print("markers", list(data.get("markers", {}).keys()))
for mk, mv in data.get("markers", {}).items():
    tr = mv.get("transforms", {})
    print(f"  {mk}: resource={mv.get('resource')} transforms={len(tr)}")
    if tr:
        tid = next(iter(tr))
        print("   sample", tid, tr[tid])

print("chains count", len(data.get("chains", {})))
if data.get("chains"):
    ck = next(iter(data["chains"]))
    print(" chain sample", ck, data["chains"][ck][:3] if data["chains"][ck] else None)

print("decals count", len(data.get("decals", [])))
if data.get("decals"):
    d = data["decals"][0]
    print(" decal0", d.get("blueprintPath"), "transforms", len(d.get("transforms", [])))
    if d.get("transforms"):
        print("  t0", d["transforms"][0])

print("props count", len(data.get("props", [])))
if data.get("props"):
    p = data["props"][0]
    print(" prop0", p.get("blueprintPath"), "transforms", len(p.get("transforms", [])))
    if p.get("transforms"):
        print("  t0", p["transforms"][0])

print("wind", data.get("windSpeed"), data.get("windDirection"))
print("skybox", data.get("skybox"))
print("sunRA/DA", data.get("sunRA"), data.get("sunDA"), "sunPos", data.get("sunPosition"))

for k, v in data.items():
    s = len(json.dumps(v, separators=(",", ":")))
    if s > 5000:
        print(f"  large key {k}: {s} bytes")

raw = r"D:\zz Map New\Beispielkarten\1\Textures\heightmap.raw"
b = open(raw, "rb").read()
res = data["heightmapResolution"]
vals = struct.unpack("<" + "H" * (res * res), b)
print("height min/max/mean", min(vals), max(vals), sum(vals) / len(vals))
print("normalized", min(vals) / 65535.0, max(vals) / 65535.0)

tex = r"D:\zz Map New\Beispielkarten\1\Textures"
for fn in os.listdir(tex):
    p = os.path.join(tex, fn)
    print("tex", fn, os.path.getsize(p))

# Key order as in file head
with open(path, "r", encoding="utf-8") as f:
    head = f.read(4000)
print("--- HEAD TAIL CHECK ---")
print(head[:1500])
# Check formatting: CRLF, indent 2 spaces
print("uses CRLF", "\r\n" in open(path, "rb").read(200).decode("utf-8", errors="ignore"))
print("indent sample line:", repr(open(path, "r", encoding="utf-8").readline()))
print("indent2:", repr(open(path, "r", encoding="utf-8").readlines()[1]))
