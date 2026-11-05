import '../../models/game_data.dart';
import 'battle_sim.dart';

/// The enemy's brain. It sees the same state the player sees and plays by
/// the same rules: the only edge it gets is the income multiplier the sim
/// already applies per difficulty.
///
/// [me] and [level] are configurable so tests can pit two AIs against
/// each other.
class EnemyAi {
  EnemyAi(this.sim, {this.me = Side.enemy, Difficulty? level})
    : level = level ?? sim.difficulty,
      def = sim.data.aiFor(level ?? sim.difficulty);

  final BattleSim sim;
  final Side me;
  final Difficulty level;
  final AiDef def;
  double _wait = 0;

  /// When a turret becomes worth buying, by difficulty.
  double get turretAt => level == Difficulty.hard ? 8 : 30;

  /// Normal keeps one turret; Hard builds a second one later.
  int get maxTurrets => level == Difficulty.hard ? 2 : 1;

  /// How many player units in our half before we drop the meteor. Twice
  /// as many anywhere on the lane also counts, so a stalled front line
  /// in the middle still gets broken.
  int get meteorThreshold => level == Difficulty.hard ? 3 : 4;

  /// The AI keeps a short queue so it can still react.
  static const int maxQueue = 2;

  /// Hard saves up for Dino Riders once the opening is over.
  static const double hardSaveAfter = 15;

  void update(double dt) {
    if (sim.outcome != null) return;
    _wait -= dt;
    if (_wait > 0) return;
    _wait += def.thinkEvery;
    think();
  }

  void think() {
    final st = sim[me];
    // Every difficulty evolves as soon as it can, like a player would.
    if (sim.canEvolveSide(me)) {
      sim.evolve(me);
      return;
    }
    if (def.useMeteor &&
        sim.meteorReady(me) &&
        (enemiesInMyHalf() >= meteorThreshold ||
            sim.aliveOf(me.other).length >= meteorThreshold * 2)) {
      sim.castMeteor(me);
    }
    if (def.buyTurret &&
        st.turretCount < maxTurrets &&
        sim.time >= (st.turretCount == 0 ? turretAt : 60) &&
        st.gold >= sim.eraOf(me).turret.cost + (st.turretCount == 0 ? 0 : 150)) {
      sim.buyTurret(me);
      return;
    }
    if (_upgrade()) return;
    if (st.queue.length >= maxQueue) return;
    final pick = choose();
    if (pick != null) sim.queueUnit(me, pick);
  }

  /// When the AI starts buying upgrades and how much gold it keeps for
  /// units on top of the price. Easy never upgrades.
  double? get upgradeAfter => switch (level) {
    Difficulty.easy => null,
    Difficulty.normal => 90,
    Difficulty.hard => 45,
  };

  double get upgradeReserve => level == Difficulty.hard ? 200 : 350;

  /// Order the AI upgrades in: its army first, then its turrets.
  static const upgradeOrder = [
    'melee_damage',
    'melee_armor',
    'ranged_damage',
    'turret_damage',
    'ranged_armor',
    'turret_range',
  ];

  /// Buys the cheapest next upgrade level it can afford with gold to spare
  /// (never while under pressure: units first then).
  bool _upgrade() {
    final after = upgradeAfter;
    if (after == null || sim.time < after || underThreat(350)) return false;
    String? best;
    int? bestCost;
    for (final id in upgradeOrder) {
      final cost = sim.upgradeCost(me, id);
      if (cost == null) continue;
      if (bestCost == null || cost < bestCost) {
        best = id;
        bestCost = cost;
      }
    }
    if (best == null || sim[me].gold < bestCost! + upgradeReserve) return false;
    return sim.buyUpgrade(me, best);
  }

  /// The other side's living units on our half of the lane.
  int enemiesInMyHalf() {
    final half = sim.data.laneLength / 2;
    return sim
        .aliveOf(me.other)
        .where((u) => me == Side.enemy ? u.x >= half : u.x <= half)
        .length;
  }

  /// Other side's units within this distance of our base = under threat.
  bool underThreat([double within = 500]) {
    final front = sim.frontOf(me);
    return sim.aliveOf(me.other).any((u) => (u.x - front).abs() <= within);
  }

  /// Which unit to train next, or null to wait (broke, or saving up).
  /// Picks by role so the same plan works in every era.
  String? choose() {
    final gold = sim[me].gold;
    final era = sim.eraOf(me);
    final affordable = era.units.where((u) => u.cost <= gold).toList();
    if (affordable.isEmpty) return null;
    final role = switch (level) {
      Difficulty.easy => _easy(affordable),
      Difficulty.normal => _normal(affordable),
      Difficulty.hard => _hard(affordable, gold),
    };
    return role == null ? null : era.byRole(role)?.id;
  }

  /// Random pick, leaning toward cheap units.
  UnitRole _easy(List<UnitDef> affordable) {
    const weights = {UnitRole.melee: 4, UnitRole.ranged: 3, UnitRole.heavy: 1, UnitRole.elite: 1};
    final total = affordable.fold<int>(0, (s, u) => s + (weights[u.role] ?? 1));
    var roll = sim.rng.nextInt(total);
    for (final u in affordable) {
      roll -= weights[u.role] ?? 1;
      if (roll < 0) return u.role;
    }
    return affordable.first.role;
  }

  /// Counter the player's mix: charge ranged-heavy armies, keep a front
  /// line with ranged units behind it otherwise.
  UnitRole _normal(List<UnitDef> affordable) {
    bool can(UnitRole r) => affordable.any((u) => u.role == r);
    final theirs = sim.aliveOf(me.other).toList();
    final theirRanged = theirs.where((u) => u.def.ranged).length;
    final theirMelee = theirs.length - theirRanged;
    final myMelee = sim.aliveOf(me).where((u) => !u.def.ranged).length;
    final elite = sim.eraOf(me).byRole(UnitRole.elite);

    if (can(UnitRole.elite) && sim.time > 90 && sim[me].gold >= (elite?.cost ?? 350) + 100) {
      return UnitRole.elite;
    }
    if (theirRanged > theirMelee) {
      if (can(UnitRole.heavy)) return UnitRole.heavy;
      return UnitRole.melee;
    }
    if (myMelee < 2) return UnitRole.melee;
    if (can(UnitRole.ranged)) return UnitRole.ranged;
    return UnitRole.melee;
  }

  /// Like Normal, but saves for heavy and elite units when not pressed.
  UnitRole? _hard(List<UnitDef> affordable, double gold) {
    bool can(UnitRole r) => affordable.any((u) => u.role == r);
    final threat = underThreat();
    final myAlive = sim.aliveOf(me).length;
    final elite = sim.eraOf(me).byRole(UnitRole.elite);

    if (can(UnitRole.elite) && gold >= (elite?.cost ?? 350) + 100) return UnitRole.elite;
    if (can(UnitRole.heavy) && (sim.time > hardSaveAfter || threat)) {
      return UnitRole.heavy;
    }
    if (threat && myAlive < 2) return can(UnitRole.ranged) ? UnitRole.ranged : UnitRole.melee;
    if (sim.time > hardSaveAfter && myAlive >= 2) return null;
    return _normal(affordable);
  }
}
