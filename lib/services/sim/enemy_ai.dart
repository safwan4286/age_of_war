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
    if (def.useMeteor &&
        sim.meteorReady(me) &&
        (enemiesInMyHalf() >= meteorThreshold ||
            sim.aliveOf(me.other).length >= meteorThreshold * 2)) {
      sim.castMeteor(me);
    }
    if (def.buyTurret &&
        st.turretCount < maxTurrets &&
        sim.time >= (st.turretCount == 0 ? turretAt : 60) &&
        st.gold >= sim.data.turret.cost + (st.turretCount == 0 ? 0 : 150)) {
      sim.buyTurret(me);
      return;
    }
    if (st.queue.length >= maxQueue) return;
    final pick = choose();
    if (pick != null) sim.queueUnit(me, pick);
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
  String? choose() {
    final gold = sim[me].gold;
    final affordable = sim.data.units.where((u) => u.cost <= gold).toList();
    if (affordable.isEmpty) return null;
    return switch (level) {
      Difficulty.easy => _easy(affordable),
      Difficulty.normal => _normal(affordable),
      Difficulty.hard => _hard(affordable, gold),
    };
  }

  /// Random pick, leaning toward cheap units.
  String _easy(List<UnitDef> affordable) {
    const weights = {'clubman': 4, 'slinger': 3, 'dinorider': 1, 'chief': 1};
    final total = affordable.fold<int>(0, (s, u) => s + (weights[u.id] ?? 1));
    var roll = sim.rng.nextInt(total);
    for (final u in affordable) {
      roll -= weights[u.id] ?? 1;
      if (roll < 0) return u.id;
    }
    return affordable.first.id;
  }

  /// Counter the player's mix: charge ranged-heavy armies, keep a front
  /// line with slingers behind it otherwise.
  String _normal(List<UnitDef> affordable) {
    bool can(String id) => affordable.any((u) => u.id == id);
    final theirs = sim.aliveOf(me.other).toList();
    final theirRanged = theirs.where((u) => u.def.ranged).length;
    final theirMelee = theirs.length - theirRanged;
    final myMelee = sim.aliveOf(me).where((u) => !u.def.ranged).length;

    if (can('chief') && sim.time > 90 && sim[me].gold >= 450) return 'chief';
    if (theirRanged > theirMelee) {
      if (can('dinorider')) return 'dinorider';
      return 'clubman';
    }
    if (myMelee < 2) return 'clubman';
    if (can('slinger')) return 'slinger';
    return 'clubman';
  }

  /// Like Normal, but saves for Dino Riders and Chiefs when not pressed.
  String? _hard(List<UnitDef> affordable, double gold) {
    bool can(String id) => affordable.any((u) => u.id == id);
    final threat = underThreat();
    final myAlive = sim.aliveOf(me).length;

    if (can('chief') && gold >= 450) return 'chief';
    if (can('dinorider') && (sim.time > hardSaveAfter || threat)) {
      return 'dinorider';
    }
    if (threat && myAlive < 2) return can('slinger') ? 'slinger' : 'clubman';
    if (sim.time > hardSaveAfter && myAlive >= 2) return null;
    return _normal(affordable);
  }
}
