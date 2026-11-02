import 'package:epoch_clash/models/game_data.dart';
import 'package:epoch_clash/services/sim/battle_sim.dart';
import 'package:epoch_clash/services/sim/enemy_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final data = loadData();
  BattleSim fresh({Difficulty d = Difficulty.normal}) => BattleSim(data, difficulty: d);

  test('units.json has the six Stone Age upgrades, three levels each', () {
    expect(data.upgrades.map((u) => u.id), [
      'melee_damage',
      'melee_armor',
      'ranged_damage',
      'ranged_armor',
      'turret_damage',
      'turret_range',
    ]);
    for (final u in data.upgrades) {
      expect(u.maxLevel, 3, reason: u.id);
      expect(u.costs, orderedEquals([...u.costs]..sort()), reason: '${u.id} costs rise');
    }
  });

  test('a bad upgrade entry is skipped, not a crash', () {
    final d = GameData.fromMap({
      'upgrades': [
        {'id': 'x', 'target': 'nope', 'stat': 'damage', 'costs': [1]},
        {'id': 'y', 'target': 'melee', 'stat': 'armor', 'costs': []},
        {'id': 'z', 'target': 'turret', 'stat': 'range', 'per': 0.5, 'costs': [10, 20]},
      ],
    });
    expect(d.upgrades.map((u) => u.id), ['z']);
    expect(d.upgrade('z')!.maxLevel, 2);
  });

  test('buying pays the next level and stops at the cap', () {
    final sim = fresh();
    final s = sim[Side.player];
    s.gold = 10000;
    final costs = data.upgrade('melee_damage')!.costs;
    for (var lvl = 0; lvl < 3; lvl++) {
      final before = s.gold;
      expect(sim.buyUpgrade(Side.player, 'melee_damage'), isTrue);
      expect(before - s.gold, costs[lvl]);
    }
    expect(sim.upgradeLevel(Side.player, 'melee_damage'), 3);
    expect(sim.upgradeCost(Side.player, 'melee_damage'), isNull);
    expect(sim.buyUpgrade(Side.player, 'melee_damage'), isFalse);
  });

  test('not enough gold buys nothing', () {
    final sim = fresh();
    sim[Side.player].gold = 10;
    expect(sim.buyUpgrade(Side.player, 'turret_range'), isFalse);
    expect(sim.upgradeLevel(Side.player, 'turret_range'), 0);
    expect(sim[Side.player].gold, 10);
  });

  test('damage upgrades only touch their own class', () {
    final sim = fresh();
    sim[Side.player].gold = 10000;
    final club = place(sim, Side.player, 'clubman', 300);
    final sling = place(sim, Side.player, 'slinger', 250);
    sim.buyUpgrade(Side.player, 'melee_damage');
    sim.buyUpgrade(Side.player, 'melee_damage');
    expect(sim.unitDamage(club), closeTo(club.def.damage * 1.3, 1e-9));
    expect(sim.unitDamage(sling), sling.def.damage);
  });

  test('armor cuts the damage a unit takes', () {
    final hits = <double>[];
    for (final armored in [false, true]) {
      final sim = fresh();
      sim[Side.enemy].gold = 10000;
      if (armored) sim.buyUpgrade(Side.enemy, 'melee_armor');
      final victim = place(sim, Side.enemy, 'chief', 600);
      place(sim, Side.player, 'clubman', 600 - 40);
      final start = victim.hp;
      run(sim, 3);
      hits.add(start - victim.hp);
    }
    expect(hits[0], greaterThan(0));
    expect(hits[1], closeTo(hits[0] * 0.9, 1e-6));
  });

  test('turret upgrades raise damage and range', () {
    final sim = fresh();
    sim[Side.player].gold = 10000;
    final range = sim.turretRange(Side.player);
    sim.buyUpgrade(Side.player, 'turret_range');
    sim.buyUpgrade(Side.player, 'turret_damage');
    expect(sim.turretRange(Side.player), closeTo(range * 1.15, 1e-9));
    expect(sim.turretDamage(Side.player), closeTo(data.turret.damage * 1.2, 1e-9));
    // A unit just past the old range is now shot at.
    sim.buyTurret(Side.player, 0);
    final e = place(sim, Side.enemy, 'chief', sim.frontOf(Side.player) + range + 20);
    final hp = e.hp;
    e.state = UnitState.idle;
    run(sim, 2, each: () => e.x = sim.frontOf(Side.player) + range + 20);
    expect(e.hp, lessThan(hp));
  });

  test('Easy never upgrades; Hard does once it is rich and safe', () {
    for (final (d, expectUpgrades) in [(Difficulty.easy, false), (Difficulty.hard, true)]) {
      final sim = fresh(d: d);
      final ai = EnemyAi(sim);
      run(sim, 70, each: () {
        sim[Side.enemy].gold = 2000;
        ai.update(0.05);
      });
      final bought = sim[Side.enemy].upgrades.values.fold<int>(0, (a, b) => a + b);
      expect(bought > 0, expectUpgrades, reason: d.label);
    }
  });
}
