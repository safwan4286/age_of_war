import 'map_read.dart';

enum Difficulty {
  easy,
  normal,
  hard;

  String get label => switch (this) {
    Difficulty.easy => 'Easy',
    Difficulty.normal => 'Normal',
    Difficulty.hard => 'Hard',
  };
}

/// One unit type, read from assets/data/units.json.
class UnitDef {
  const UnitDef({
    required this.id,
    required this.name,
    required this.cost,
    required this.trainTime,
    required this.hp,
    required this.damage,
    required this.attackEvery,
    required this.range,
    required this.speed,
    required this.killReward,
    required this.xp,
    required this.width,
    required this.sprite,
    required this.frameW,
    required this.frameH,
    this.projectileSpeed = 0,
    this.auraBonus = 0,
    this.auraRadius = 0,
    this.drawScale = 1,
    this.headY = 0,
    this.frames = defaultFrames,
    this.frameTimes = const {},
  });

  final String id;
  final String name;
  final int cost;
  final double trainTime;
  final double hp;
  final double damage;
  final double attackEvery;
  final double range;
  final double speed;
  final int killReward;
  final int xp;

  /// Footprint along the lane, used for spacing.
  final double width;
  final String sprite;
  final int frameW;
  final int frameH;

  /// > 0 = ranged: attacks with a projectile at this speed.
  final double projectileSpeed;

  /// Chief: extra damage for allies within [auraRadius].
  final double auraBonus;
  final double auraRadius;

  /// World units per art pixel when drawn (frames come from the sheets
  /// at their own resolution; this sets how tall the unit stands).
  final double drawScale;

  /// Height of the standing figure in world units (where the health bar
  /// goes); 0 = use the frame height.
  final double headY;

  /// Frames per animation strip. Units built from the 4-row sheets use
  /// the defaults; units assembled from separate frames can have more.
  final Map<String, int> frames;

  static const defaultFrames = {'idle': 4, 'walk': 6, 'attack': 6, 'die': 6};

  /// Seconds per frame for idle / walk when the art needs its own pace
  /// (attack and die are timed by the sim).
  final Map<String, double> frameTimes;

  int frameCount(String anim) => frames[anim] ?? defaultFrames[anim] ?? 6;

  double frameTime(String anim, double fallback) => frameTimes[anim] ?? fallback;

  bool get ranged => projectileSpeed > 0;

  static UnitDef fromMap(Map<dynamic, dynamic> m) => UnitDef(
    id: m.str('id'),
    name: m.str('name'),
    cost: m.integer('cost', 50),
    trainTime: m.dbl('trainTime', 1.5),
    hp: m.dbl('hp', 100),
    damage: m.dbl('damage', 10),
    attackEvery: m.dbl('attackEvery', 1),
    range: m.dbl('range', 20),
    speed: m.dbl('speed', 40),
    killReward: m.integer('killReward', 50),
    xp: m.integer('xp', 40),
    width: m.dbl('width', 22),
    sprite: m.str('sprite', m.str('id')),
    frameW: m.integer('frameW', 64),
    frameH: m.integer('frameH', 64),
    projectileSpeed: m.dbl('projectileSpeed'),
    auraBonus: m.dbl('auraBonus'),
    auraRadius: m.dbl('auraRadius'),
    drawScale: m.dbl('drawScale', 1),
    headY: m.dbl('headY'),
    frames: {
      for (final e in defaultFrames.entries)
        e.key: m.sub('frames').integer(e.key, e.value),
    },
    frameTimes: {
      for (final k in const ['idle', 'walk'])
        if (m.sub('frameTimes')[k] is num) k: m.sub('frameTimes').dbl(k),
    },
  );
}

class TurretDef {
  const TurretDef({
    required this.name,
    required this.cost,
    required this.damage,
    required this.attackEvery,
    required this.range,
    required this.sellBack,
    required this.projectileSpeed,
    this.slots = 3,
  });

  final String name;
  final int cost;
  final double damage;
  final double attackEvery;
  final double range;
  final int sellBack;
  final double projectileSpeed;

  /// Turret ledges per base.
  final int slots;

  static TurretDef fromMap(Map<dynamic, dynamic> m) => TurretDef(
    name: m.str('name', 'Turret'),
    cost: m.integer('cost', 100),
    damage: m.dbl('damage', 12),
    attackEvery: m.dbl('attackEvery', 1.5),
    range: m.dbl('range', 300),
    sellBack: m.integer('sellBack', 50),
    projectileSpeed: m.dbl('projectileSpeed', 420),
    slots: m.integer('slots', 3),
  );
}

class MeteorDef {
  const MeteorDef({
    required this.cooldown,
    required this.count,
    required this.duration,
    required this.damage,
    required this.radius,
  });

  final double cooldown;
  final int count;
  final double duration;
  final double damage;
  final double radius;

  static MeteorDef fromMap(Map<dynamic, dynamic> m) => MeteorDef(
    cooldown: m.dbl('cooldown', 60),
    count: m.integer('count', 10),
    duration: m.dbl('duration', 2),
    damage: m.dbl('damage', 60),
    radius: m.dbl('radius', 60),
  );
}

class AiDef {
  const AiDef({
    required this.income,
    required this.useMeteor,
    required this.buyTurret,
    required this.thinkEvery,
  });

  final double income;
  final bool useMeteor;
  final bool buyTurret;
  final double thinkEvery;

  static AiDef fromMap(Map<dynamic, dynamic> m) => AiDef(
    income: m.dbl('income', 1),
    useMeteor: m.boolean('useMeteor', true),
    buyTurret: m.boolean('buyTurret', true),
    thinkEvery: m.dbl('thinkEvery', 0.8),
  );
}

/// What an upgrade improves.
enum UpgradeTarget { melee, ranged, turret }

enum UpgradeStat { damage, armor, range }

/// A battle upgrade bought with gold, a few levels deep. Lasts for the
/// battle (Age of War style). [per] is the bonus per level: +15% damage,
/// -10% damage taken, +15% range.
class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.target,
    required this.stat,
    required this.per,
    required this.costs,
  });

  final String id;
  final String name;
  final String desc;
  final UpgradeTarget target;
  final UpgradeStat stat;
  final double per;

  /// Cost of each level, in order; the list length is the level cap.
  final List<int> costs;

  int get maxLevel => costs.length;

  static UpgradeDef? fromMap(Map<dynamic, dynamic> m) {
    final target = UpgradeTarget.values.where((t) => t.name == m['target']).firstOrNull;
    final stat = UpgradeStat.values.where((t) => t.name == m['stat']).firstOrNull;
    final raw = m['costs'];
    final costs = [if (raw is List) for (final c in raw) if (c is num) c.toInt()];
    if (target == null || stat == null || costs.isEmpty || m.str('id').isEmpty) return null;
    return UpgradeDef(
      id: m.str('id'),
      name: m.str('name', m.str('id')),
      desc: m.str('desc'),
      target: target,
      stat: stat,
      per: m.dbl('per', 0.1),
      costs: costs,
    );
  }
}

/// Positions on the base picture, as fractions of its size (0,0 = top
/// left, x from the rock side toward the lane). Measured per base art.
class BaseArt {
  const BaseArt({
    this.height = 300,
    this.gate = 0.56,
    this.slots = const [(0.86, 0.36), (0.55, 0.27), (0.28, 0.10)],
    this.turretW = 0,
    this.cliffFrom = 0,
  });

  /// Drawn height in world units; width follows the picture.
  final double height;

  /// Where the gate is across the picture: units appear here.
  final double gate;

  /// Turret ledges: (x, y) of the spot a turret stands on.
  final List<(double, double)> slots;

  /// Turret width as a fraction of the picture's width (sized to the
  /// ledges); 0 = the layout default.
  final double turretW;

  /// The rock behind the base continues past the screen edge, repeated
  /// from this x (fraction of the picture) outward.
  final double cliffFrom;

  static BaseArt fromMap(Map<dynamic, dynamic> m) {
    final raw = m['slots'];
    final slots = <(double, double)>[
      if (raw is List)
        for (final s in raw)
          if (s is List && s.length == 2 && s.first is num && s.last is num)
            ((s.first as num).toDouble(), (s.last as num).toDouble()),
    ];
    const d = BaseArt();
    return BaseArt(
      height: m.dbl('height', d.height),
      gate: m.dbl('gate', d.gate),
      slots: slots.isEmpty ? d.slots : slots,
      turretW: m.dbl('turretW'),
      cliffFrom: m['cliff'] is List && (m['cliff'] as List).isNotEmpty && (m['cliff'] as List).first is num
          ? ((m['cliff'] as List).first as num).toDouble()
          : 0,
    );
  }
}

/// Where a background layer is drawn: [top] and [height] in world units
/// (the world is 540 tall). Its width follows the picture.
class LayerPlace {
  const LayerPlace({this.top = 0, this.height = 540});

  final double top;
  final double height;

  static LayerPlace fromMap(Map<dynamic, dynamic> m) =>
      LayerPlace(top: m.dbl('top'), height: m.dbl('height', 540));
}

/// Everything balance-related, from one JSON file so tuning needs no code.
class GameData {
  const GameData({
    required this.laneLength,
    required this.baseWidth,
    required this.spawnGap,
    required this.startGold,
    required this.trickle,
    required this.queueMax,
    this.popCap = 10,
    this.baseArt = const BaseArt(),
    this.layers = const {},
    this.upgrades = const [],
    required this.evolveXp,
    required this.baseHp,
    required this.turret,
    required this.meteor,
    required this.units,
    required this.ai,
  });

  final double laneLength;

  /// Each base covers this much of its lane end. Units spawn at the base
  /// front (x = baseWidth for the player, laneLength - baseWidth for the
  /// enemy) and attack a base from there.
  final double baseWidth;

  /// Minimum distance between two units of the same side.
  final double spawnGap;
  final int startGold;
  final double trickle;
  final int queueMax;

  /// Most units a side can have alive + in training.
  final int popCap;

  /// Where things sit on the base picture (view only).
  final BaseArt baseArt;

  /// Background layer placement by name: sky, hills, near (view only).
  final Map<String, LayerPlace> layers;

  LayerPlace layer(String name) => layers[name] ?? const LayerPlace();

  /// Battle upgrades, in the order the upgrade menu shows them.
  final List<UpgradeDef> upgrades;

  UpgradeDef? upgrade(String id) => upgrades.where((u) => u.id == id).firstOrNull;
  final int evolveXp;
  final double baseHp;
  final TurretDef turret;
  final MeteorDef meteor;
  final List<UnitDef> units;
  final Map<Difficulty, AiDef> ai;

  UnitDef unit(String id) => units.firstWhere((u) => u.id == id);

  AiDef aiFor(Difficulty d) => ai[d] ?? const AiDef(
    income: 1,
    useMeteor: true,
    buyTurret: true,
    thinkEvery: 0.8,
  );

  static GameData fromMap(Map<dynamic, dynamic> m) {
    final lane = m.sub('lane');
    final eco = m.sub('economy');
    final ai = m.sub('ai');
    return GameData(
      laneLength: lane.dbl('length', 1600),
      baseWidth: lane.dbl('baseWidth', 120),
      spawnGap: lane.dbl('spawnGap', 26),
      startGold: eco.integer('startGold', 175),
      trickle: eco.dbl('trickle', 2),
      queueMax: eco.integer('queueMax', 5),
      popCap: eco.integer('popCap', 10),
      baseArt: BaseArt.fromMap(m.sub('base').sub('art')),
      layers: {
        for (final e in m.sub('world').sub('layers').entries)
          if (e.value is Map) '${e.key}': LayerPlace.fromMap(e.value as Map),
      },
      evolveXp: eco.integer('evolveXp', 4000),
      baseHp: m.sub('base').dbl('hp', 1000),
      turret: TurretDef.fromMap(m.sub('turret')),
      meteor: MeteorDef.fromMap(m.sub('meteor')),
      units: [for (final u in m.subs('units')) UnitDef.fromMap(u)],
      upgrades: [
        for (final u in m.subs('upgrades')) ?UpgradeDef.fromMap(u),
      ],
      ai: {
        for (final d in Difficulty.values)
          if (ai[d.name] is Map) d: AiDef.fromMap(ai[d.name] as Map),
      },
    );
  }
}
