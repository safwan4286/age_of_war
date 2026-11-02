/// Every asset path in one place. Flame's image cache already prefixes
/// `assets/images/`, so [Img] paths are relative to that.
class AppAssets {
  AppAssets._();

  static const unitsJson = 'assets/data/units.json';
}

/// Flame image keys (relative to assets/images/).
class Img {
  Img._();

  static const unitAnims = ['idle', 'walk', 'attack', 'die'];

  /// Horizontal strip for one unit animation. Enemy art adds `_red`.
  static String unit(String sprite, String anim, {bool red = false}) =>
      'units/stone_${sprite}_$anim${red ? '_red' : ''}.png';

  static String base({bool red = false}) =>
      'bases/stone_base${red ? '_red' : ''}.png';

  /// Rock that continues the base off screen (repeated, mirrored).
  static String cliff({bool red = false}) =>
      'bases/stone_cliff${red ? '_red' : ''}.png';

  static String turret({bool red = false}) =>
      'bases/stone_turret${red ? '_red' : ''}.png';

  /// The catapult right after a throw.
  static String turretFire({bool red = false}) =>
      'bases/stone_turret_fire${red ? '_red' : ''}.png';

  static const bgSky = 'bg/stone_sky.png';
  static const bgHills = 'bg/stone_hills.png';
  static const bgNear = 'bg/stone_near.png';

  static const stone = 'fx/stone.png';
  static const rock = 'fx/rock.png';
  static const meteor = 'fx/meteor.png';
  static const blast = 'fx/blast.png';

  static List<String> all(Iterable<String> sprites) => [
    for (final s in sprites)
      for (final a in unitAnims)
        for (final red in [false, true]) unit(s, a, red: red),
    for (final red in [false, true]) ...[
      base(red: red),
      cliff(red: red),
      turret(red: red),
      turretFire(red: red),
    ],
    bgSky,
    bgHills,
    bgNear,
    stone,
    rock,
    meteor,
    blast,
  ];
}

/// Flutter `Image.asset` paths for HUD and menus.
class UiImg {
  UiImg._();

  static String unitIcon(String sprite) =>
      'assets/images/icons/icon_$sprite.png';

  /// Whole figure for menus; `red` = the enemy's colours.
  static String unitPose(String sprite, {bool red = false}) =>
      'assets/images/icons/pose_$sprite${red ? '_red' : ''}.png';

  /// Square head-and-shoulders portrait for the shop cards.
  static String unitCard(String sprite) =>
      'assets/images/icons/card_$sprite.png';
  static const turret = 'assets/images/icons/icon_turret.png';
  static const meteor = 'assets/images/icons/icon_meteor.png';
  static const evolve = 'assets/images/icons/icon_evolve.png';
  static const gold = 'assets/images/icons/icon_gold.png';
  static const xp = 'assets/images/icons/icon_xp.png';
  static const star = 'assets/images/ui/star.png';
  static const starEmpty = 'assets/images/ui/star_empty.png';
  static const lock = 'assets/images/ui/lock.png';
}
