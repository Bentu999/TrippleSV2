# SanMap Editor (Godot)

Externer Karteneditor für **Sanctuary: Shattered Sun** (`.sanmap` Format Version 3).

## Voraussetzungen

- [Godot 4.3+](https://godotengine.org/download) (Standard / Forward+)

## Starten (Entwicklung)

1. Godot öffnen → **Import** / **Open**
2. Ordner `SanMapEditor` wählen (`project.godot`)
3. F5 / Play

## Portable EXE bauen (für andere)

Voraussetzung: Godot **4.7.2** + Export-Templates (`Editor → Manage Export Templates → Download and Install`).

```powershell
powershell -ExecutionPolicy Bypass -File SanMapEditor/tools/build_windows_dist.ps1
```

Ergebnis: `dist/SanMapEditor/`

| Inhalt | Bedeutung |
|--------|-----------|
| `SanMapEditor.exe` | Editor inkl. aller Projektdaten (**PCK eingebettet**, keine separate `.pck`) |
| `Enviroment/` | Terrain-/Skybox-Texturen (~3 GB) **neben** der EXE — zu groß für sinnvolles Einpacken in die EXE |
| `README.txt` | Kurzinfo für Empfänger |

Preset: `export_presets.cfg` → Windows Desktop, `binary_format/embed_pck=true`. Das MCP-Addon wird beim Export ausgeschlossen.

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
| **Mirror X / Mirror Z** | Dock MIRROR (F5/F6) | Pinsel spiegeln um die Kartenmitte im Editor. Spawns und Alloys spiegeln auf Z um 2 m versetzt, damit das Paar **im Spiel** gleich weit von den Kanten liegt (Speichern rechnet `z_welt = length - z - 1`). |

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

**Koordinaten:** Laut `Sanctuary/MapUtils.cs` (`TextureToWorldOrigin`) bleiben Heightmap/TGA im Texture-Space; nur Marker/Props/Playable-Z werden beim Speichern mit `z_world = length - z - 1` ins World-Space geschrieben. Beim Laden wird World-Z wieder in Editor-Z zurückgerechnet. Ein Gleichstand der Höhenprobe (flache Karte) gilt als World-Space — sonst würde der nächste Speichervorgang die Spawns ein zweites Mal spiegeln und die Spieler starten gegenüber dem Marker. Raster werden **nicht** gespiegelt.

**Oberfläche:** Die Editor-UI ist Englisch. Schrift und Fenster-Skalierung wachsen mit der Fensterhöhe, damit die Leiste auf großen Monitoren lesbar bleibt. Schicht-Namen im Mal-Menü sind die originalen Texturdateinamen; das Feld `name` an Stratum-Layern wird nicht geschrieben (offizielle Karten lassen es weg).

**Alloys:** Rotation ist Identität (wie Spawns / MapUtils). Y wird 0,4 m über der Terrainhöhe gespeichert, damit die Markierung auf dem Boden liegt statt darin. Im Editor erscheinen Alloys als flache Scheibe. Bereits platzierte Spiegel-Paare bleiben an der alten Stelle, bis sie neu gesetzt werden.

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
