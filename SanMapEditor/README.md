# SanMap Editor (Godot)

Externer Karteneditor für **Sanctuary: Shattered Sun** (`.sanmap` Format Version 3).

## Voraussetzungen

- [Godot 4.3+](https://godotengine.org/download) (Standard / Forward+)

## Starten

1. Godot öffnen → **Import** / **Open**
2. Ordner `SanMapEditor` wählen (`project.godot`)
3. F5 / Play

## Bedienung

| Eingabe | Aktion |
|---------|--------|
| RMB ziehen | Kamera orbit |
| MMB ziehen | Pan |
| Mausrad | Zoom |
| LMB | Aktives Werkzeug (Pinsel / Marker) |

## Dateiformat (wie offizielle Karten, z. B. The Forge)

```
MeineKarte/
  MeineKarte.sanmap
  Textures/
    heightmap.raw          # 16-bit LE, heightmapResolution²
    stratums_1_4.tga       # 2×Kartengröße, RGBA splat
    stratums_5_8.tga
    tint_colors.tga
    tint_geometry.tga
```

`.sanmap` ist JSON (2 Spaces, CRLF), Schema Version 3. Spawns heißen `Army_N` und bekommen passende `armies`-Einträge.

## MVP-Funktionen

- Neue Karte / Öffnen / Speichern
- 3D-Terrain aus Heightmap
- Pinsel: Anheben, Absenken, Glätten, Ebnen
- Marker: Spawn, Alloys
- PlayableArea-Overlay
- Wasser-Toggle + Level

## Nächste Schritte (geplant)

- Stratum-/Splatmap-Texturing
- Props & Decals
- Lighting-/Fog-Panel
- Import offizieller Heightmaps aus dem Spiel-Editor
