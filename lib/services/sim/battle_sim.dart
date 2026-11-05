import 'dart:math' as math;

import '../../models/game_data.dart';

/// Who owns something. The player's base is on the left (x = 0), the
/// enemy's on the right (x = laneLength).
enum Side {
  player,
  enemy;

  Side get other => this == Side.player ? Side.enemy : Side.player;

  /// +1 walks right, -1 walks left.
  int get dir => this == Side.player ? 1 : -1;
}

enum UnitState { walking, idle, attacking, dying }

class SimUnit {
  SimUnit({
    required this.id,
    required this.def,
    required this.side,
    required this.x,
  }) : hp = def.hp;

  final int id;
  final UnitDef def;
  final Side side;
  double x;
  double hp;
  UnitState state = UnitState.walking;

  /// Seconds until the next hit lands while attacking.
  double cooldown = 0;
  double dyingFor = 0;

  bool get alive => state != UnitState.dying;
  double get hpFraction => (hp / def.hp).clamp(0.0, 1.0);
}

enum ProjectileKind { stone, rock }

class SimProjectile {
  SimProjectile({
    required this.id,
    required this.side,
    required this.kind,
    required this.x,
    required this.targetX,
    required this.targetId,
    required this.damage,
    required this.speed,
    this.slot = -1,
    this.sprite = 'stone',
    this.shooter,
  }) : startX = x;

  final int id;
  final Side side;
  final ProjectileKind kind;
  double x;
  final double startX;
  double targetX;

  /// Unit id, or -1 = the enemy base.
  final int targetId;
  final double damage;
  final double speed;

  /// Turret ledge it was fired from, or -1 for a unit's shot.
  final int slot;

  /// fx image name the view draws.
  final String sprite;

  /// The unit type that shot it (null for turrets): where it appears.
  final UnitDef? shooter;
  bool done = false;

  /// 0 → 1 along the flight, for the arc the view draws.
  double get progress {
    final total = (targetX - startX).abs();
    if (total < 1) return 1;
    return ((x - startX).abs() / total).clamp(0.0, 1.0);
  }
}

class MeteorImpact {
  MeteorImpact({
    required this.caster,
    required this.x,
    required this.at,
    this.sprite = 'meteor',
    this.blast = 'blast',
    this.size = 110,
    this.blastSize = 160,
    this.fallTime = 0.4,
    this.style = 'meteor',
  });

  final Side caster;

  /// Seconds in the air before landing, and how it falls (see MeteorDef).
  final double fallTime;
  final String style;

  /// Drawn widths (world units) of the falling thing and its impact.
  final double size;
  final double blastSize;

  /// fx image names: the falling thing and its impact.
  final String sprite;
  final String blast;
  final double x;

  /// Sim time of the impact.
  final double at;
}

class SideState {
  SideState({required this.gold, required this.baseHp, int turretSlots = 3})
    : turrets = List.filled(turretSlots, false),
      turretCooldowns = List.filled(turretSlots, 0);

  double gold;
  int xp = 0;

  /// Index into GameData.eras.
  int era = 0;
  double baseHp;
  final List<UnitDef> queue = [];
  double trainLeft = 0;

  /// One entry per turret ledge on the base: built or empty.
  final List<bool> turrets;
  final List<double> turretCooldowns;
  double meteorCharge = 0;

  /// Upgrade id -> level bought this battle.
  final Map<String, int> upgrades = {};
  int kills = 0;
  int goldEarned = 0;

  bool get hasTurret => turrets.contains(true);
  int get turretCount => turrets.where((t) => t).length;
}

enum SimEventType {
  spawn,
  attack,
  hit,
  kill,
  baseHit,
  projectile,
  meteorCast,
  meteorImpact,
  turretBought,
  turretSold,
  upgraded,
  evolved,
  gameOver,
}

/// Something the view may want to show (floating gold, a flash, a shake).
class SimEvent {
  const SimEvent(this.type, this.side, {this.unitId = -1, this.x = 0, this.amount = 0, this.meteor});

  final SimEventType type;

  /// For kill: the side that got the reward. Otherwise the side involved.
  final Side side;
  final int unitId;
  final double x;
  final double amount;

  /// For meteorImpact: which one landed (its blast art).
  final MeteorImpact? meteor;
}

enum BattleOutcome { victory, defeat }

/// The whole battle as plain Dart: no Flutter, no Flame. The game view
/// calls [step] every frame and draws whatever is in [units],
/// [projectiles] and [meteors]. Deterministic for a given [seed].
class BattleSim {
  BattleSim(this.data, {this.difficulty = Difficulty.normal, int seed = 7})
    : rng = math.Random(seed) {
    sides = {
      for (final s in Side.values)
        s: SideState(
          gold: data.startGold.toDouble(),
          baseHp: data.baseHp,
          turretSlots: data.turret.slots,
        ),
    };
  }

  final GameData data;
  final Difficulty difficulty;
  final math.Random rng;
  late final Map<Side, SideState> sides;

  final List<SimUnit> units = [];
  final List<SimProjectile> projectiles = [];
  final List<MeteorImpact> meteors = [];
  final List<SimEvent> _events = [];

  double time = 0;
  BattleOutcome? outcome;
  int _nextId = 1;

  /// How long the death animation plays before a unit is removed (the
  /// last 40% fades out).
  static const double dyingTime = 1.0;

  /// Melee units deal their first hit half an attack in.
  static const double windup = 0.5;

  SideState operator [](Side s) => sides[s]!;

  /// Where a side's units spawn, and where its base can be hit.
  double frontOf(Side s) =>
      s == Side.player ? data.baseWidth : data.laneLength - data.baseWidth;

  double incomeMultiplier(Side s) =>
      s == Side.enemy ? data.aiFor(difficulty).income : 1.0;

  Iterable<SimUnit> aliveOf(Side s) =>
      units.where((u) => u.side == s && u.alive);

  /// Living units plus the ones in training; capped at [GameData.popCap].
  int population(Side s) => aliveOf(s).length + this[s].queue.length;

  /// The era a side is in.
  EraDef eraOf(Side s) => data.era(this[s].era);

  /// Full base health for a side in its current era.
  double maxHp(Side s) => eraOf(s).baseHp;

  bool meteorReady(Side s) => this[s].meteorCharge >= eraOf(s).meteor.cooldown;

  double meteorFraction(Side s) =>
      (this[s].meteorCharge / eraOf(s).meteor.cooldown).clamp(0.0, 1.0);

  /// XP a side needs to leave its era; 0 in the last era.
  int evolveXpOf(Side s) => this[s].era < data.eras.length - 1 ? eraOf(s).evolveXp : 0;

  bool canEvolveSide(Side s) => evolveXpOf(s) > 0 && this[s].xp >= evolveXpOf(s);

  bool get canEvolve => canEvolveSide(Side.player);

  /// 3 stars = base above 66%, 2 = above 33%, else 1. 0 when lost.
  int get stars {
    if (outcome != BattleOutcome.victory) return 0;
    final f = this[Side.player].baseHp / maxHp(Side.player);
    if (f > 0.66) return 3;
    if (f > 0.33) return 2;
    return 1;
  }

  /// Events since the last call, oldest first.
  List<SimEvent> drainEvents() {
    final out = List<SimEvent>.of(_events);
    _events.clear();
    return out;
  }

  // ----------------------------------------------------------- commands

  /// Pays and queues a unit. False when broke, the queue is full, the
  /// population cap is reached or the battle is over.
  bool queueUnit(Side s, String unitId) {
    if (outcome != null) return false;
    final d = data.unit(unitId);
    // Only the side's current era is for sale.
    if (d.era != eraOf(s).id) return false;
    final st = this[s];
    if (st.queue.length >= data.queueMax || st.gold < d.cost) return false;
    if (population(s) >= data.popCap) return false;
    st.gold -= d.cost;
    if (st.queue.isEmpty) st.trainLeft = d.trainTime;
    st.queue.add(d);
    return true;
  }

  /// Builds a turret on ledge [slot] (or the first empty ledge).
  bool buyTurret(Side s, [int? slot]) {
    final st = this[s];
    final i = slot ?? st.turrets.indexOf(false);
    if (outcome != null || i < 0 || i >= st.turrets.length) return false;
    final cost = eraOf(s).turret.cost;
    if (st.turrets[i] || st.gold < cost) return false;
    st.gold -= cost;
    st.turrets[i] = true;
    st.turretCooldowns[i] = 0;
    _events.add(SimEvent(SimEventType.turretBought, s, unitId: i));
    return true;
  }

  /// Sells the turret on ledge [slot] for [TurretDef.sellBack] gold.
  bool sellTurret(Side s, int slot) {
    final st = this[s];
    if (outcome != null || slot < 0 || slot >= st.turrets.length) return false;
    if (!st.turrets[slot]) return false;
    st.turrets[slot] = false;
    st.gold += eraOf(s).turret.sellBack;
    _events.add(SimEvent(SimEventType.turretSold, s, unitId: slot));
    return true;
  }

  // ------------------------------------------------------------ upgrades

  int upgradeLevel(Side s, String id) => this[s].upgrades[id] ?? 0;

  /// Gold for the next level of [id], or null when maxed or unknown.
  int? upgradeCost(Side s, String id) {
    final u = data.upgrade(id);
    if (u == null) return null;
    final lvl = upgradeLevel(s, id);
    return lvl >= u.maxLevel ? null : u.costs[lvl];
  }

  /// Buys the next level of upgrade [id].
  bool buyUpgrade(Side s, String id) {
    final cost = upgradeCost(s, id);
    final st = this[s];
    if (outcome != null || cost == null || st.gold < cost) return false;
    st.gold -= cost;
    st.upgrades[id] = upgradeLevel(s, id) + 1;
    _events.add(SimEvent(SimEventType.upgraded, s, amount: st.upgrades[id]!.toDouble()));
    return true;
  }

  /// Total bonus a side has for [target]/[stat] (0.3 = +30%).
  double bonus(Side s, UpgradeTarget target, UpgradeStat stat) {
    var b = 0.0;
    for (final u in data.upgrades) {
      if (u.target == target && u.stat == stat) b += u.per * upgradeLevel(s, u.id);
    }
    return b;
  }

  UpgradeTarget _classOf(UnitDef d) => d.ranged ? UpgradeTarget.ranged : UpgradeTarget.melee;

  /// A unit's damage per hit with its side's upgrades.
  double unitDamage(SimUnit u) =>
      u.def.damage * (1 + bonus(u.side, _classOf(u.def), UpgradeStat.damage));

  /// Share of incoming damage a unit still takes (armor upgrades).
  double damageTaken(SimUnit u) =>
      (1 - bonus(u.side, _classOf(u.def), UpgradeStat.armor)).clamp(0.2, 1.0);

  double turretDamage(Side s) =>
      eraOf(s).turret.damage * (1 + bonus(s, UpgradeTarget.turret, UpgradeStat.damage));

  double turretRange(Side s) =>
      eraOf(s).turret.range * (1 + bonus(s, UpgradeTarget.turret, UpgradeStat.range));

  /// Moves a side into the next era: new roster, turret type, special and
  /// a stronger base (it gains the difference in full health). Units
  /// already on the lane and in training stay as they are.
  bool evolve(Side s) {
    if (outcome != null || !canEvolveSide(s)) return false;
    final st = this[s];
    final before = maxHp(s);
    st.era++;
    st.baseHp += maxHp(s) - before;
    _events.add(SimEvent(SimEventType.evolved, s, amount: st.era.toDouble()));
    return true;
  }

  /// Rains meteors over the other side's army (only its units get hurt).
  /// With no army on the lane, the rocks fall on the other side's half.
  bool castMeteor(Side s) {
    if (outcome != null || !meteorReady(s)) return false;
    final m = eraOf(s).meteor;
    this[s].meteorCharge = 0;
    final (lo, hi) = meteorZone(s);
    for (var i = 0; i < m.count; i++) {
      meteors.add(
        MeteorImpact(
          caster: s,
          x: lo + rng.nextDouble() * (hi - lo),
          // Each one is in the air for fallTime before it lands.
          at: time + m.fallTime + m.duration * i / m.count,
          sprite: m.sprite,
          blast: m.blast,
          size: m.size,
          blastSize: m.blastSize,
          fallTime: m.fallTime,
          style: m.style,
        ),
      );
    }
    _events.add(SimEvent(SimEventType.meteorCast, s));
    return true;
  }

  /// Where [caster]'s meteors land: the span of the other side's living
  /// units, padded by the blast radius and kept between the bases.
  (double, double) meteorZone(Side caster) {
    final laneLo = frontOf(Side.player), laneHi = frontOf(Side.enemy);
    final xs = aliveOf(caster.other).map((u) => u.x).toList();
    if (xs.isEmpty) {
      final half = data.laneLength / 2;
      return caster == Side.player ? (half, laneHi) : (laneLo, half);
    }
    final r = eraOf(caster).meteor.radius / 2;
    final lo = xs.reduce(math.min) - r, hi = xs.reduce(math.max) + r;
    return (math.max(laneLo, lo), math.min(laneHi, hi));
  }

  // --------------------------------------------------------------- tick

  void step(double dt) {
    if (outcome != null) return;
    dt = dt.clamp(0.0, 0.1);
    time += dt;
    for (final s in Side.values) {
      _economy(s, dt);
      _train(s);
    }
    for (final s in Side.values) {
      _unitsOf(s, dt);
    }
    _engage();
    for (final s in Side.values) {
      _turret(s, dt);
    }
    _projectiles(dt);
    _meteors();
    _cleanup(dt);
    _checkOutcome();
  }

  void _economy(Side s, double dt) {
    final st = this[s];
    st.gold += data.trickle * dt * incomeMultiplier(s);
    final cd = eraOf(s).meteor.cooldown;
    if (st.meteorCharge < cd) {
      st.meteorCharge = math.min(cd, st.meteorCharge + dt);
    }
    if (st.queue.isNotEmpty) st.trainLeft -= dt;
  }

  void _train(Side s) {
    final st = this[s];
    if (st.queue.isEmpty || st.trainLeft > 0) return;
    final d = st.queue.first;
    final x = frontOf(s);
    // Wait until the spawn point is clear of our own units.
    for (final u in aliveOf(s)) {
      if ((u.x - x).abs() < data.spawnGap + d.width / 2) return;
    }
    st.queue.removeAt(0);
    st.trainLeft = st.queue.isEmpty ? 0 : st.queue.first.trainTime;
    final unit = SimUnit(id: _nextId++, def: d, side: s, x: x);
    units.add(unit);
    _events.add(SimEvent(SimEventType.spawn, s, unitId: unit.id, x: x));
  }

  /// Nearest living enemy ahead of [u] (units never pass each other).
  SimUnit? _targetFor(SimUnit u) {
    SimUnit? best;
    for (final e in aliveOf(u.side.other)) {
      if (best == null || (e.x - u.x).abs() < (best.x - u.x).abs()) best = e;
    }
    return best;
  }

  /// Nearest living friend ahead of [u], in its walking direction.
  SimUnit? _friendAhead(SimUnit u) {
    SimUnit? best;
    for (final f in aliveOf(u.side)) {
      if (identical(f, u)) continue;
      final ahead = (f.x - u.x) * u.side.dir;
      if (ahead <= 0) continue;
      if (best == null || ahead < (best.x - u.x) * u.side.dir) best = f;
    }
    return best;
  }

  double _auraMultiplier(SimUnit u) {
    for (final f in aliveOf(u.side)) {
      if (identical(f, u) || f.def.auraBonus <= 0) continue;
      if ((f.x - u.x).abs() <= f.def.auraRadius) return 1 + f.def.auraBonus;
    }
    return 1;
  }

  void _unitsOf(Side s, double dt) {
    // Front units first, so the ones behind see where they stopped.
    final list = aliveOf(s).toList()
      ..sort((a, b) => ((b.x - a.x) * s.dir).sign.toInt());
    for (final u in list) {
      final target = _targetFor(u);
      final enemyFront = frontOf(s.other);
      final reachUnit = target == null
          ? -1.0
          : u.def.range + (u.def.width + target.def.width) / 2;
      final distUnit = target == null ? double.infinity : (target.x - u.x).abs();
      final distBase = (enemyFront - u.x).abs();
      final reachBase = u.def.range + u.def.width / 2;

      if (target != null && distUnit <= reachUnit + _eps) {
        _attack(u, dt, target: target);
        continue;
      }
      if (distBase <= reachBase + _eps) {
        _attack(u, dt);
        continue;
      }

      // Walk, but stop behind a friend, before an enemy, and at the base.
      var limit = enemyFront - s.dir * (u.def.width / 2);
      if (target != null) {
        final stop = target.x - s.dir * reachUnit;
        limit = s == Side.player ? math.min(limit, stop) : math.max(limit, stop);
      }
      final friend = _friendAhead(u);
      if (friend != null) {
        final stop = friend.x - s.dir * ((u.def.width + friend.def.width) / 2 + 4);
        limit = s == Side.player ? math.min(limit, stop) : math.max(limit, stop);
      }
      final want = u.x + s.dir * u.def.speed * dt;
      final next = s == Side.player ? math.min(want, limit) : math.max(want, limit);
      final moved = (next - u.x) * s.dir;
      if (moved > 0.01) {
        u.x = next;
        u.state = UnitState.walking;
      } else {
        u.state = UnitState.idle;
      }
      // Arriving in reach starts the wind-up this tick, so whichever side
      // walks in first doesn't lose a tick. Ties go to the player, whose
      // units act first.
      final inReach =
          (target != null && (target.x - u.x).abs() <= reachUnit + _eps) ||
          (enemyFront - u.x).abs() <= reachBase + _eps;
      if (inReach) {
        u.state = UnitState.attacking;
        u.cooldown = u.def.attackEvery * windup;
      }
    }
  }

  static const double _eps = 0.001;

  /// After both sides moved: anyone who is now in reach starts the wind-up
  /// this tick, so a fight never depends on which side closed the gap.
  void _engage() {
    for (final u in units) {
      if (!u.alive || u.state == UnitState.attacking) continue;
      final target = _targetFor(u);
      final enemyFront = frontOf(u.side.other);
      final inReach =
          (target != null &&
              (target.x - u.x).abs() <=
                  u.def.range + (u.def.width + target.def.width) / 2 + _eps) ||
          (enemyFront - u.x).abs() <= u.def.range + u.def.width / 2 + _eps;
      if (inReach) {
        u.state = UnitState.attacking;
        u.cooldown = u.def.attackEvery * windup;
      }
    }
  }

  void _attack(SimUnit u, double dt, {SimUnit? target}) {
    if (u.state != UnitState.attacking) {
      // The wind-up starts counting next tick, same as for a unit that
      // walked into reach this tick (see _unitsOf).
      u.state = UnitState.attacking;
      u.cooldown = u.def.attackEvery * windup;
      return;
    }
    u.cooldown -= dt;
    if (u.cooldown > 0) return;
    u.cooldown += u.def.attackEvery;
    final dmg = unitDamage(u) * _auraMultiplier(u);
    _events.add(SimEvent(SimEventType.attack, u.side, unitId: u.id, x: u.x));
    if (u.def.ranged) {
      _shoot(
        side: u.side,
        kind: ProjectileKind.stone,
        fromX: u.x,
        targetX: target?.x ?? frontOf(u.side.other),
        targetId: target?.id ?? -1,
        damage: dmg,
        speed: u.def.projectileSpeed,
        sprite: u.def.projectile,
        shooter: u.def,
      );
    } else if (target != null) {
      _damageUnit(target, dmg, by: u.side);
    } else {
      _damageBase(u.side.other, dmg);
    }
  }

  void _turret(Side s, double dt) {
    final st = this[s];
    if (!st.hasTurret) return;
    final front = frontOf(s);
    final range = turretRange(s);
    SimUnit? best;
    for (final e in aliveOf(s.other)) {
      final d = (e.x - front).abs();
      if (d > range) continue;
      if (best == null || d < (best.x - front).abs()) best = e;
    }
    for (var i = 0; i < st.turrets.length; i++) {
      if (!st.turrets[i]) continue;
      final cd = st.turretCooldowns[i] - dt;
      if (cd > 0 || best == null) {
        st.turretCooldowns[i] = cd > 0 ? cd : 0;
        continue;
      }
      final t = eraOf(s).turret;
      st.turretCooldowns[i] = t.attackEvery;
      _shoot(
        side: s,
        kind: ProjectileKind.rock,
        fromX: front,
        targetX: best.x,
        targetId: best.id,
        damage: turretDamage(s),
        speed: t.projectileSpeed,
        slot: i,
        sprite: t.projectile,
      );
    }
  }

  void _shoot({
    required Side side,
    required ProjectileKind kind,
    required double fromX,
    required double targetX,
    required int targetId,
    required double damage,
    required double speed,
    int slot = -1,
    String sprite = 'stone',
    UnitDef? shooter,
  }) {
    final p = SimProjectile(
      id: _nextId++,
      side: side,
      kind: kind,
      x: fromX,
      targetX: targetX,
      targetId: targetId,
      damage: damage,
      speed: speed,
      slot: slot,
      sprite: sprite,
      shooter: shooter,
    );
    projectiles.add(p);
    _events.add(SimEvent(SimEventType.projectile, side, unitId: p.id, x: fromX));
  }

  void _projectiles(double dt) {
    for (final p in projectiles) {
      if (p.done) continue;
      SimUnit? target;
      if (p.targetId >= 0) {
        for (final u in units) {
          if (u.id == p.targetId) target = u;
        }
        // Follow a living target; a dead one leaves the stone to land.
        if (target != null && target.alive) p.targetX = target.x;
      } else {
        p.targetX = frontOf(p.side.other);
      }
      final move = p.speed * dt;
      final gap = p.targetX - p.x;
      if (gap.abs() <= move) {
        p.x = p.targetX;
        p.done = true;
        if (p.targetId < 0) {
          _damageBase(p.side.other, p.damage);
        } else if (target != null && target.alive) {
          _damageUnit(target, p.damage, by: p.side);
        }
      } else {
        p.x += gap.sign * move;
      }
    }
  }

  void _meteors() {
    for (final m in meteors) {
      if (m.at > time) continue;
      final def = eraOf(m.caster).meteor;
      for (final u in aliveOf(m.caster.other).toList()) {
        if ((u.x - m.x).abs() <= def.radius) {
          _damageUnit(u, def.damage, by: m.caster);
        }
      }
      _events.add(SimEvent(SimEventType.meteorImpact, m.caster, x: m.x, meteor: m));
    }
    meteors.removeWhere((m) => m.at <= time);
  }

  void _damageUnit(SimUnit t, double amount, {required Side by}) {
    if (!t.alive) return;
    amount *= damageTaken(t);
    t.hp -= amount;
    _events.add(SimEvent(SimEventType.hit, t.side, unitId: t.id, x: t.x, amount: amount));
    if (t.hp > 0) return;
    t.hp = 0;
    t.state = UnitState.dying;
    t.dyingFor = 0;
    final st = this[by];
    final reward = (t.def.killReward * incomeMultiplier(by)).round();
    st.gold += reward;
    st.xp += t.def.xp;
    st.kills++;
    st.goldEarned += reward;
    _events.add(SimEvent(SimEventType.kill, by, unitId: t.id, x: t.x, amount: reward.toDouble()));
  }

  void _damageBase(Side owner, double amount) {
    final st = this[owner];
    st.baseHp = math.max(0, st.baseHp - amount);
    _events.add(SimEvent(SimEventType.baseHit, owner, x: frontOf(owner), amount: amount));
  }

  void _cleanup(double dt) {
    for (final u in units) {
      if (!u.alive) u.dyingFor += dt;
    }
    units.removeWhere((u) => !u.alive && u.dyingFor >= dyingTime);
    projectiles.removeWhere((p) => p.done);
  }

  void _checkOutcome() {
    if (this[Side.enemy].baseHp <= 0) {
      outcome = BattleOutcome.victory;
    } else if (this[Side.player].baseHp <= 0) {
      outcome = BattleOutcome.defeat;
    }
    if (outcome != null) {
      _events.add(SimEvent(SimEventType.gameOver, Side.player));
    }
  }
}
