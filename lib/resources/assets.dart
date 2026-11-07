import '../models/game_data.dart';

/// Every asset path in one place. Flame's image cache already prefixes
/// `assets/images/`, so [Img] paths are relative to that.
class AppAssets {
  AppAssets._();

  static const unitsJson = 'assets/data/units.json';
}

/// Flame image keys (relative to assets/images/). Art is named by era:
/// `units/medieval_knight_walk.png`, `bases/stone_base_red.png`...
class Img {
  Img._();

  static const unitAnims = ['idle', 'walk', 'attack', 'die'];
  static const bgLayers = ['sky', 'hills', 'near'];

  static String _red(bool red) => red ? '_red' : '';

  /// Horizontal strip for one unit animation. Enemy art adds `_red`.
  static String unit(UnitDef def, String anim, {bool red = false}) =>
      'units/${def.era}_${def.sprite}_$anim${_red(red)}.png';

  static String base(String era, {bool red = false}) => 'bases/${era}_base${_red(red)}.png';

  /// What continues the base off screen (repeated, mirrored).
  static String cliff(String era, {bool red = false}) => 'bases/${era}_cliff${_red(red)}.png';

  static String turret(String era, {bool red = false}) => 'bases/${era}_turret${_red(red)}.png';

  /// The turret right after a shot.
  static String turretFire(String era, {bool red = false}) =>
      'bases/${era}_turret_fire${_red(red)}.png';

  static String bg(String era, String layer) => 'bg/${era}_$layer.png';

  /// Effects by name (projectiles, specials, blasts).
  static String fx(String name) => 'fx/$name.png';

  /// Stones and rocks tumble in flight; arrows and bolts point where
  /// they fly.
  static const spinning = {'stone', 'rock'};

  /// Drawn width in world units; height follows the picture.
  static double fxWidth(String name) => switch (name) {
    'stone' => 12,
    'rock' => 22,
    'medieval_arrow' => 30,
    'medieval_bolt' => 44,
    'gunpowder_ball' => 7,
    'gunpowder_cannonball' => 16,
    'modern_bullet' => 18,
    'modern_shell' => 26,
    'modern_rocket' => 36,
    _ => 20,
  };

  /// Shots fired with gunpowder: a muzzle flash and smoke where they
  /// leave, this big (1 = a musket).
  static const firearms = {
    'gunpowder_ball': 1.0,
    'gunpowder_cannonball': 2.2,
    'modern_bullet': 0.8,
    'modern_shell': 2.6,
    'modern_rocket': 1.6,
  };

  /// Everything one era draws in battle.
  static List<String> era(EraDef e) => [
    for (final u in e.units)
      for (final a in unitAnims)
        for (final red in [false, true]) unit(u, a, red: red),
    for (final red in [false, true]) ...[
      base(e.id, red: red),
      cliff(e.id, red: red),
      turret(e.id, red: red),
      turretFire(e.id, red: red),
    ],
    for (final l in bgLayers) bg(e.id, l),
    ...{
      for (final u in e.units)
        if (u.ranged) fx(u.projectile),
      fx(e.turret.projectile),
      fx(e.meteor.sprite),
      fx(e.meteor.blast),
    },
  ];

  static List<String> all(GameData data) => [for (final e in data.eras) ...era(e)];
}

/// Flutter `Image.asset` paths for HUD and menus.
class UiImg {
  UiImg._();

  static String icon(String name) => 'assets/images/icons/$name.png';

  static String unitIcon(String sprite) => icon('icon_$sprite');

  /// Whole figure for menus; `red` = the enemy's colours.
  static String unitPose(String sprite, {bool red = false}) =>
      'assets/images/icons/pose_$sprite${red ? '_red' : ''}.png';

  /// Square head-and-shoulders portrait for the shop cards.
  static String unitCard(String sprite) => 'assets/images/icons/card_$sprite.png';

  /// An era's HUD icons (special, evolve, turret), from units.json.
  static String special(EraDef e) => icon(e.icon('special', 'icon_meteor'));
  static String evolve(EraDef e) => icon(e.icon('evolve', 'icon_evolve'));
  static String turret(EraDef e) => icon(e.icon('turret', 'icon_turret'));

  static const gold = 'assets/images/icons/icon_gold.png';
  static const xp = 'assets/images/icons/icon_xp.png';
  static const star = 'assets/images/ui/star.png';
  static const starEmpty = 'assets/images/ui/star_empty.png';
  static const lock = 'assets/images/ui/lock.png';
}
