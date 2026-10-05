#!/usr/bin/env python3
"""Create Maps/testprobs with every Environment prop on an even grid."""

from __future__ import annotations

import json
import math
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Maps" / "test 8"
DST = ROOT / "Maps" / "testprobs"
SANPACK = Path(
    r"D:/SteamLibrary/steamapps/common/Sanctuary Shattered Sun Playtest"
    r"/engine/Sanctuary_Data/Gamedata/Environment.sanpack"
)


def collect_props(sanpack: Path) -> list[str]:
    props: list[str] = []
    with zipfile.ZipFile(sanpack) as zf:
        for entry in zf.namelist():
            name = entry.replace("\\", "/")
            if not name.endswith(".santp") or "/Props/" not in name:
                continue
            idx = name.find("Environment/")
            if idx < 0:
                idx = name.find("Enviroment/")
            game_path = name if idx < 0 else name[idx:]
            game_path = game_path.replace("Enviroment/", "Environment/")
            if game_path not in props:
                props.append(game_path)
    props.sort()
    return props


def load_heights(path: Path, resolution: int) -> list[float]:
    raw = path.read_bytes()
    expected = resolution * resolution * 2
    if len(raw) < expected:
        raise RuntimeError(f"Heightmap too small: {path} ({len(raw)} < {expected})")
    heights: list[float] = []
    for i in range(resolution * resolution):
        lo = raw[i * 2]
        hi = raw[i * 2 + 1]
        heights.append((lo | (hi << 8)) / 65535.0)
    return heights


def sample_height(
    heights: list[float],
    resolution: int,
    map_w: float,
    map_l: float,
    map_h: float,
    wx: float,
    wz: float,
) -> float:
    u = wx / map_w * (resolution - 1)
    v = wz / map_l * (resolution - 1)
    x0 = int(max(0, min(resolution - 2, math.floor(u))))
    z0 = int(max(0, min(resolution - 2, math.floor(v))))
    tx = u - x0
    tz = v - z0
    h00 = heights[z0 * resolution + x0]
    h10 = heights[z0 * resolution + x0 + 1]
    h01 = heights[(z0 + 1) * resolution + x0]
    h11 = heights[(z0 + 1) * resolution + x0 + 1]
    h0 = h00 * (1.0 - tx) + h10 * tx
    h1 = h01 * (1.0 - tx) + h11 * tx
    return (h0 * (1.0 - tz) + h1 * tz) * map_h


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Template map missing: {SRC}")
    if not SANPACK.exists():
        raise SystemExit(f"Environment.sanpack missing: {SANPACK}")

    props = collect_props(SANPACK)
    print(f"Found {len(props)} props")

    if DST.exists():
        shutil.rmtree(DST)
    (DST / "Textures").mkdir(parents=True)

    for name in (
        "heightmap.raw",
        "stratums_1_4.tga",
        "stratums_5_8.tga",
        "tint_colors.tga",
        "tint_geometry.tga",
    ):
        shutil.copy2(SRC / "Textures" / name, DST / "Textures" / name)
    if (SRC / "preview.png").exists():
        shutil.copy2(SRC / "preview.png", DST / "preview.png")

    with open(SRC / "test 8.sanmap", encoding="utf-8") as f:
        data = json.load(f)

    map_w = float(data["width"])
    map_l = float(data["length"])
    map_h = float(data["height"])
    resolution = int(data["heightmapResolution"])
    heights = load_heights(DST / "Textures" / "heightmap.raw", resolution)

    n = len(props)
    cols = math.ceil(math.sqrt(n))
    rows = math.ceil(n / cols)
    margin = 16.0
    usable_w = map_w - 2.0 * margin
    usable_l = map_l - 2.0 * margin
    dz = usable_l / max(rows - 1, 1) if rows > 1 else 0.0

    # Build row lengths so every row (incl. partial last) spans full width.
    row_counts: list[int] = []
    remaining = n
    for _ in range(rows):
        count = min(cols, remaining)
        row_counts.append(count)
        remaining -= count

    prop_groups = []
    index = 0
    for row, count in enumerate(row_counts):
        z = map_l * 0.5 if rows == 1 else margin + row * dz
        dx = usable_w / max(count - 1, 1) if count > 1 else 0.0
        for col in range(count):
            x = map_w * 0.5 if count == 1 else margin + col * dx
            y = sample_height(heights, resolution, map_w, map_l, map_h, x, z)
            prop_groups.append(
                {
                    "blueprintPath": props[index],
                    "transforms": [
                        {
                            "position": {"x": x, "y": y, "z": z},
                            "rotation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
                            "scale": {"x": 1.0, "y": 1.0, "z": 1.0},
                        }
                    ],
                }
            )
            index += 1
    spacing_x = usable_w / max(cols - 1, 1) if cols > 1 else 0.0

    data["name"] = "testprobs"
    data["credits"] = f"All {n} Environment props on even grid ({cols}x{rows})"
    data["props"] = prop_groups
    data["areas"] = {
        "PlayableArea": {"x": 0.0, "y": 0.0, "width": map_w, "height": map_l}
    }

    out_path = DST / "testprobs.sanmap"
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

    print(f"Wrote {out_path}")
    print(
        f"Grid {cols}x{rows} (row sizes {row_counts}), "
        f"spacing ~{spacing_x:.1f} x {dz:.1f}, margin {margin}"
    )
    first = prop_groups[0]["transforms"][0]["position"]
    last = prop_groups[-1]["transforms"][0]["position"]
    print(f"First: {props[0]} @ {first}")
    print(f"Last:  {props[-1]} @ {last}")


if __name__ == "__main__":
    main()
