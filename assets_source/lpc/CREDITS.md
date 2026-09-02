# Art credits — staged source material for Phase 7 (real biome art)

Raw, unmodified downloads staged here for a later integration phase (cropping
individual tiles into `assets/*.png` and wiring them into Godot
`TileSetAtlasSource`s) — mirrors the same two-step approach and credit
discipline as the JS original's `assets/lpc/CREDITS.md`. Nothing in this
folder has been cropped, recolored, or otherwise modified yet.

## `terrains/lpc-terrains/terrain-v7.png`

**"[LPC] Terrains"** — a compilation by bluecarrot16 combining tiles from many
individually-licensed LPC-family submissions. Full per-tile attribution chain
(preserved verbatim from the pack's own credits file):

- Liberated Pixel Cup (LPC) Base Assets — Lanea Zimmerman ("Sharm") — CC-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0
- [LPC] Farming tilesets, magic animations and UI elements — Daniel Eddeland ("Daneeklu") — CC-BY-SA 3.0 / GPL 3.0
- ZRPG Tiles — Richard Kettering ("Jetrel"), Zachariah Husiar ("Zabin"), Hyptosis, Lanea Zimmerman ("Sharm"), Open Pixel Project — CC-BY-SA 3.0+
- LPC C.Nilsson — Casper Nilsson — CC-BY-SA 3.0 / GPL 3.0
- Frozen Lake [LPC] — Buko Studios (commissioned by PlayCraft) — CC-BY 3.0
- LPC Animated Water and waterfalls — ZaPaper — CC-BY-SA 3.0
- LPC More Water Transitions — billknye — CC-BY-SA 3.0 / GPL 3.0
- [LPC] Sand+Rock Alt Colors — William.Thompsonj, Daniel Eddeland — CC-BY-SA 3.0 / GPL 3.0
- [LPC] Colorful Sand + Deep Water! — Nushio — CC-BY-SA 3.0 / GPL 3.0
- LPC terrain extension — caeles — CC-BY-SA 3.0 / GPL 3.0
- RPG Tiles: Cobble stone paths & town objects — Zachariah Husiar ("Zabin"), Daniel Eddeland ("Daneeklu"), Richard Kettering ("Jetrel"), Hyptosis, Redshrike, Bertram — CC-BY-SA 3.0
- RPG Terrains — Rayane Félix ("RayaneFLX") — CC-BY-SA 3.0

Source: https://opengameart.org/content/lpc-terrains — **overall license: CC-BY-SA 3.0/4.0, share-alike, attribution required** (matches the license already accepted in this project for `castle_wall.png`/`castle_floor.png`).

Contains, among others: grass, dirt, rock, stone, cobblestone, mud, water,
**snow, ice** (→ Frostpeak ground), **sand** (→ Badlands ground), **bog**
(→ Gloomfen ground), plus mud/grass variants (→ Verdantwood ground).

## `base_assets/LPC Base Assets/tiles/*.png`

Same source already used for `grass.png`/`dungeon_wall.png`/`castle_wall.png`/
etc. — re-pulled here for sheets not yet extracted into `assets/`:
`lava.png`, `lavarock.png` (→ Badlands interior/geyser hazard), `brackish.png`
(→ Gloomfen swamp ground/water), `mountains.png` (→ Frostpeak ridge accent,
volcano entrance-prop base), `stairs.png`/`cement.png`/`cementstair.png`
(→ Golden Plains ancient-barrow interior), `bridges.png`/`hole.png`/
`holek.png`/`holemid.png` (→ brittle-bridge hazard tiles, ravine divider),
`dirt2.png` (→ interior floor variety).

- Author: Lanea Zimmerman ("Sharm")
- License: **OGA-BY 3.0** (attribution only, no share-alike)
- Source: https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles

## `cavern_ruins/LPC_cavern_ruins/cavern_ruins.png`

**"LPC Cavern and Ruin Tiles"** by Reemax, combining:

- Lava/water/cave-wall/stair/cement tiles — based on Lanea Zimmerman ("Sharm")'s LPC tiles
- Wooden structures — Hyptosis
- Carpet, cobblestone, blue-gray brick floors, brown/gray rocks, columns, obelisk, coffin, purple brick wall, mine cart tracks, fallen ceiling/rock sign, brick arc, stone fence, big stone sign, thrones — Tuomo Untinen (some bases by Johann C)
- Obelisk base, gray columns, brown rocks — Johann C
- Monk statue (statue itself) — Johannes Sjölund
- Cell windows — Lanea Zimmerman ("Sharm") / William Thompson (from "LPC Dungeon Elements")
- Wooden box crate — Daniel Eddeland (LPC farming tileset)
- Empty armors, monk statue base — Johannes Sjölund
- Imp statue — Stephen Challener + William Thompson (imp), Tuomo Untinen (statue base/recolor)
- Castle floors (small tiles) — Daniel Armstrong ("HughSpectrum")

License: **CC-BY-SA 3.0 / GPL 3.0 / GPL 2.0** (multi-licensed, share-alike, attribution required)
Source: https://opengameart.org/content/lpc-cavern-and-ruin-tiles

Contains a glowing blue pentacle/magic circle (→ **Verdantwood's Druid Circle**
entrance prop), a stone brick archway near water (→ **Frostpeak's Watchtower
Ruin** or **Gloomfen's Submerged Temple**), and an obelisk (→ **Golden
Plains' Ancient Barrow**) — strong candidates for 3 of the 5 entrance-prop
illustrations still needed.

## Coverage summary (against the Phase 7 placeholder inventory)

| Biome | Outdoor ground | Interior wall/floor | Hazard tiles | Entrance prop |
|---|---|---|---|---|
| Frostpeak | Terrains (snow/ice) | Base Assets (mountains/dungeon) + Terrains (ice/stone) | Terrains (ice) + Base Assets (bridges) | Cavern & Ruins (stone arc) |
| Verdantwood | Terrains (grass/mud) | Base Assets (dungeon/dirt2) | Terrains (mud/grass) | Cavern & Ruins (magic circle) |
| Badlands | Terrains (sand) + Base Assets (lava/lavarock) | Base Assets (lava/lavarock) | Base Assets (lava/hole) | **not yet found** — likely composite of Base Assets' `mountains.png` + `lava.png` at integration time, no single ready-made volcano sprite located |
| Gloomfen | Terrains (bog) + Base Assets (brackish) | Base Assets (brackish/dungeon) | Terrains (mud) + Base Assets (bridges) | Cavern & Ruins (stone arc) |
| Golden Plains | (already real — `grass.png`) | Base Assets (stairs/cement/dirt) | n/a | Cavern & Ruins (obelisk) |

4 of 5 entrance props have a strong candidate; the volcano is the one gap,
flagged for a composite approach (or a further one-off search) rather than
blocking on it, per the approved plan.
