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
| LMB | Aktives Werkzeug (Pinsel / Marker / Prop) |
| Ctrl+Z | Undo |
| Ctrl+Y / Ctrl+Shift+Z | Redo |

Props: Tool **Prop** wählen, Blueprint im Dock auswählen, LMB auf Terrain. Scale und Zufalls-Yaw im Dock. Mirror gilt auch hier. Im Editor erscheinen farbige Proxy-Boxen; im Spiel laden die `.santp`-Blueprints.

## Dateiformat (wie offizielle Karten, z. B. The Forge)

```
MeineKarte/
  MeineKarte.sanmap
  preview.png              # Top-Down-Vorschau (max. 1024²)
  Textures/
    heightmap.raw          # 16-bit LE, heightmapResolution²
    stratums_1_4.tga       # splat size == heightmapResolution
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
- Props platzieren (Blueprint-Gruppen, Undo, Proxy-Vorschau)
- PlayableArea-Overlay
- Wasser-Toggle + Level

## Nächste Schritte (geplant)

- Prop-Mesh-Vorschau (.santp)
- Decals
- Lighting-/Fog-Panel
- Import offizieller Heightmaps aus dem Spiel-Editor
