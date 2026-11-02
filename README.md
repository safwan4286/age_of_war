# Epoch Clash — Stone Age slice

2D lane battle (Age of War-style) in Flutter + Flame. One age (Stone Age), four
units, a turret, a meteor special, three AI difficulties, stars per difficulty.

## Run

```bash
cd ~/Documents/Private/epoch_clash
fvm use 3.47.5          # once
fvm flutter pub get
fvm flutter test        # 36 tests: data, sim, AI
fvm flutter run         # landscape, Android or iOS
```

iOS first run: `cd ios && pod install`, then open `Runner.xcworkspace` once to
pick a signing team. Bundle / application id: `app.epochclash.game`.

## How it fits together

| Layer | Where | Notes |
|---|---|---|
| Balance data | `assets/data/units.json` | All numbers live here. No code change to rebalance. |
| Rules | `lib/services/sim/battle_sim.dart` | Pure Dart, deterministic per seed, no Flutter. |
| Enemy brain | `lib/services/sim/enemy_ai.dart` | Same rules as the player; only edge is income ×0.8/1.0/1.25. |
| View | `lib/features/battle/game/` | Flame `BattleGame` steps the sim and mirrors it into components. |
| HUD | `lib/features/battle/widgets/` | Flutter widgets on GetX Rx values, refreshed ~10×/s. |
| Screens | `lib/features/{menu,difficulty,battle,results,settings}` | Kindose pattern: controller + binding + screen. |
| Saves | `lib/services/save_service.dart` | One Hive box: best stars, wins, settings, tutorial flag. |

## Art pipeline

- **Units (current method)**: 3 Gemini sheets per unit on magenta (walk 4×2, attack 3×2,
  death + idle 4×2) in `tools/art/source/<unit>_frames/` with a `spec.json`, then
  `python3 tools/art/build_unit.py tools/art/source/<unit>_frames/spec.json .`
  It cuts the poses, drops floating extras, keeps a dropped weapon with its pose, scales every
  sheet to the idle height, anchors the feet, writes strips + red variants + icon and patches
  `units.json`. Done: Clubman (single all-states sheet), Slinger (3 sheets).
- **Frames exported from an AI video tool** (one transparent strip per animation, equal square frames)
  go in the same spec as `{"file": ..., "cell": 640, "anim": "walk"}`; those frames keep their own
  positions (one camera). Slinger: idle and walk from video frames, attack and death from Gemini (a row named `_...` is skipped).
  Chief and Dino Rider: idle, walk and death from video frames, attack from a Gemini sheet.
  `"match": {"walk": false}` keeps a sheet at its own scale (the running raptor is lower than it stands).

- **Units**: your Gemini sheets in `tools/art/source/` → `python3 tools/art/slice_sheets.py tools/art/source .`
  removes the background (solid or fake checkerboard) and the sparkle, cuts the 4 rows
  (idle 4 / walk 6 / attack 6 / die 6), aligns the feet, writes strips and red enemy variants and
  portrait icons, and prints frame size + drawScale for `units.json`.
- **Scene art**: your sheets in `tools/art/source/assets/` → `python3 tools/art/process_assets.py tools/art/source/assets .`
  (sky, hills, bush hedge + painted dirt lane, cave, catapult idle/fire, rock, meteor, unit and meteor icons).
- **Still placeholder** (blast, slinger stone, gold/XP/evolve icons, stars, launcher icons):
  `python3 tools/art/gen_placeholders.py .` fills only files that don't exist yet.
- Order when regenerating: `slice_sheets.py` → `process_assets.py` → `gen_placeholders.py`.
- `python3 tools/check_assets.py` verifies every path and strip size.

- **World (current)**: Gemini sheets in `tools/art/source/stone_world/` → `python3 tools/art/build_world.py .`
  keys the magenta, removes the sparkle and edge lines, turns purple smoke grey, finds the base's
  3 plank ledges and its gate and writes them to `units.json` (`base.art`), sizes the turret to the
  ledges, and cuts the effects grid. The rock past the screen edge is `bases/stone_cliff.png`, repeated
  mirrored by the game: from `stone_world/stone_cliff.png` when that sheet exists, else a strip of the base. Layer placement is `units.json` → `world.layers`
  (sky, hills, near: top and height in world units). Background layers are rebuilt from the sheets when
  `world.bgFromSheets` is true: the previous layout redrawn in the unit style (sky, meadow hills, hedge + sand plain).
  The meteor impact comes from `stone_world/stone_blast.png` (3x2 fire-to-smoke frames). HUD icons
  (gold, XP, meteor, evolve, turret, stars, lock) come from `stone_world/stone_icons.png` (4x2 grid).
  The previous art is in `tools/art/source/old_world/`.

## Upgrades

- Six battle upgrades in `units.json` → `upgrades` (melee/ranged damage and armor, turret damage and
  range), three levels each, lasting for the battle. The sim applies them (`BattleSim.unitDamage`,
  `damageTaken`, `turretDamage`, `turretRange`); the HUD's muscle button opens the menu.
- The AI upgrades too: Hard after 45 s, Normal after 90 s, Easy never; only with gold to spare and
  not while under attack. Tests: `test/upgrade_test.dart`.

## UI and screen sizes

- Look: "stone & ember" cartoon UI drawn in code (`lib/widgets/game_ui.dart`): stone panels, glossy
  outlined buttons (`GameTone.gold/stone/ember/leaf`), rounded bars. Fonts: Lilita One (titles,
  buttons, numbers) and Nunito (sentences), both OFL.
- Responsive like Kindose: `DeviceManager` + `.sp` (`lib/services/responsiveness/`), reference
  800x380 landscape, scale clamped 0.82-1.25, system text scale capped at 1.15. The shared widgets
  take design units and scale themselves; screens use `.sp` for raw sizes. `FitScreen` lays a
  screen out at a max width and scales it down on short phones, so nothing overflows.

## Layout (matches the art bible)

- Horizon (back edge of the plain) at 62% of the screen height, walk line (feet) at 77%.
- HUD only in the corners: base HP + specials + gold/population/XP top-left, enemy HP + speed/pause top-right,
  unit cards + queue bottom-left, turret menu bottom-right.
- The base is drawn from `units.json` → `base.art`: drawn height, gate position and the turret ledges as
  fractions of the picture. New base art = new numbers, no code.
- 3 turret ledges per base, population cap 10.

## Known gaps (slice scope)

- No audio yet.
- Evolve shows a "Medieval coming soon" teaser.
- Two equal AIs can stall at mid-lane; humans break it with meteor timing. Watch for stalls in playtests.
- Dino Rider sheet: attack frame 6 and die frame 1 were broken in the source; the slicer reuses neighbouring frames.
