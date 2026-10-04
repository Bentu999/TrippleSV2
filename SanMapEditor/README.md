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

## Playable Area und Infinite Terrain

Sanctuary setzt die Karte außerhalb des spielbaren Bereichs mit **Infinite Terrain** fort (Randspiegelung / Fortsetzung in die Ferne). Das ist ein Engine-Feature und **nicht abschaltbar**.

| Einstellung | Wo | Wirkung |
|-------------|-----|---------|
| **Width / Length** | Dock KARTE | Gesamte authored Map (m) |
| **Playable Area** (X, Z/Y, Width, Length) | Top-Bar „Karte“ → PLAYABLE AREA | Spielbarer Rechteck-Bereich in `.sanmap` → `areas.PlayableArea`; im Editor als cyanes Rechteck inkl. Eckpfosten sichtbar |
| **Fade Start / Fade Dist** | Dock PLAYABLE AREA | `fadeStartDistance` / `fadeDistance` – Übergang des Infinite Terrain im Spiel |
| **Mirror X / Mirror Z** | Dock MIRROR (F5/F6) | Nur Editor-Pinsel-Symmetrie, **kein** Welt-Spiegel |

Empfehlung: Map größer als die Arena wählen und Playable Area einschieben, damit ein gestalteter Randstreifen vor dem Infinite Terrain liegt. Neue Karten starten mit Playable = **halbe Kartengröße, zentriert** (wie The Forge); „Volle Karte“ und „Zentrieren“ stehen im Karte-Menü. Beim Resize der Map bleiben kleinere Playable-Rechtecke erhalten (werden nur an die neuen Grenzen geklemmt).

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

`.sanmap` ist JSON (2 Spaces, CRLF), Schema Version 3. Spawns heißen `Army_N` und bekommen passende `armies`-Einträge (`Army_1/3/5…` → faction 1, `Army_2/4/6…` → faction 2 — wie The Forge).

**Koordinaten:** Laut `Sanctuary/MapUtils.cs` (`TextureToWorldOrigin`) bleiben Heightmap/TGA im Texture-Space; nur Marker/Props/Playable-Z werden beim Speichern mit `z_world = length - z - 1` ins World-Space geschrieben (und beim Laden zurück). Raster werden **nicht** gespiegelt — das hatte die Karte im Spiel links/rechts vertauscht.

## MVP-Funktionen

- Neue Karte / Öffnen / Speichern
- 3D-Terrain aus Heightmap
- Pinsel: Anheben, Absenken, Glätten, Ebnen
- Marker: Spawn, Alloys
- Props platzieren (Blueprint-Gruppen, Undo, Proxy-Vorschau)
- PlayableArea-Overlay (3D-Rahmen + 2D-Outline) + Editor im Karte-Menü (X/Z, Größe, volle Karte)
- Neue Karten starten ohne Wasser; Wasser im Karte-Menü aktivierbar
- Fade-Felder (`fadeStartDistance` / `fadeDistance`) im Dock
- Wasser-Toggle + Level

## Nächste Schritte (geplant)

- Prop-Mesh-Vorschau (.santp)
- Decals
- Lighting-/Fog-Panel
- Import offizieller Heightmaps aus dem Spiel-Editor
