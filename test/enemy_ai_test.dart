import 'package:epoch_clash/models/game_data.dart';
import 'package:epoch_clash/services/sim/battle_sim.dart';
import 'package:epoch_clash/services/sim/enemy_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final data = loadData();

  (BattleSim, EnemyAi) setup(Difficulty d, {int seed = 7}) {
    final sim = BattleSim(data, difficulty: d, seed: seed);
    return (sim, EnemyAi(sim));
  }

  void play(BattleSim sim, EnemyAi ai, double seconds, {EnemyAi? other}) {
    run(sim, seconds, each: () {
      ai.update(0.05);
      other?.update(0.05);
    });
  }

  test('the AI trains units and never overspends', () {
    for (final d in Difficulty.values) {
      final (sim, ai) = setup(d);
      var minGold = double.infinity;
      run(sim, 120, each: () {
        ai.update(0.05);
        if (sim[Side.enemy].gold < minGold) minGold = sim[Side.enemy].gold;
      });
      expect(minGold, greaterThanOrEqualTo(0), reason: d.label);
      expect(
        sim[Side.enemy].kills + sim.units.length + sim[Side.enemy].queue.length,
        greaterThan(0),
        reason: d.label,
      );
    }
  });

  test('an idle player loses on every difficulty', () {
    for (final d in Difficulty.values) {
      final (sim, ai) = setup(d);
      play(sim, ai, 900);
      expect(sim.outcome, BattleOutcome.defeat, reason: d.label);
    }
  });

  test('Easy never buys a turret or casts the meteor', () {
    final (sim, ai) = setup(Difficulty.easy);
    sim[Side.player].gold = 100000;
    run(sim, 300, each: () {
      ai.update(0.05);
      if (sim.aliveOf(Side.player).length < 6) {
        sim.queueUnit(Side.player, 'clubman');
      }
    });
    expect(sim[Side.enemy].hasTurret, isFalse);
    expect(sim.meteorReady(Side.enemy) || sim.outcome != null, isTrue);
  });

  test('Normal waits 30 s for its turret, Hard buys one early', () {
    final (n, nai) = setup(Difficulty.normal);
    play(n, nai, 25);
    expect(n[Side.enemy].hasTurret, isFalse);
    n[Side.enemy].gold = 1000;
    play(n, nai, 10);
    expect(n[Side.enemy].turretCount, 1);

    final (h, hai) = setup(Difficulty.hard);
    h[Side.enemy].gold = 1000;
    play(h, hai, 10);
    expect(h[Side.enemy].turretCount, 1);
  });

  test('Hard adds a second turret after a minute; Normal stays at one', () {
    final (h, hai) = setup(Difficulty.hard);
    final (n, nai) = setup(Difficulty.normal);
    for (final (sim, ai) in [(h, hai), (n, nai)]) {
      run(sim, 70, each: () {
        sim[Side.enemy].gold = 1000;
        ai.update(0.05);
      });
    }
    expect(h[Side.enemy].turretCount, 2);
    expect(n[Side.enemy].turretCount, 1);
  });

  test('meteor thresholds: Hard at 3 units in its half, Normal at 4', () {
    for (final (d, needed) in [(Difficulty.hard, 3), (Difficulty.normal, 4)]) {
      final (sim, ai) = setup(d);
      run(sim, 61);
      for (var i = 0; i < needed - 1; i++) {
        place(sim, Side.player, 'chief', 900 + i * 40.0);
      }
      ai.think();
      expect(sim.meteorReady(Side.enemy), isTrue, reason: '${d.label} early');
      place(sim, Side.player, 'chief', 900 + needed * 40.0);
      ai.think();
      expect(sim.meteorReady(Side.enemy), isFalse, reason: '${d.label} cast');
    }
  });

  test('Normal answers a ranged army with Dino Riders', () {
    final (sim, ai) = setup(Difficulty.normal);
    for (var i = 0; i < 3; i++) {
      place(sim, Side.player, 'slinger', 300 + i * 40.0);
    }
    sim[Side.enemy].gold = 250;
    expect(ai.choose(), 'dinorider');
  });

  test('Hard saves up instead of spamming cheap units', () {
    final (sim, ai) = setup(Difficulty.hard);
    run(sim, 20);
    place(sim, Side.enemy, 'clubman', 1300);
    place(sim, Side.enemy, 'clubman', 1250);
    sim[Side.enemy].gold = 120;
    expect(ai.choose(), isNull);
  });

  test('a big army anywhere draws the meteor, even mid-lane', () {
    final (sim, ai) = setup(Difficulty.normal);
    run(sim, 61);
    for (var i = 0; i < 8; i++) {
      place(sim, Side.player, 'clubman', 300 + i * 40.0);
    }
    ai.think();
    expect(sim.meteorReady(Side.enemy), isFalse);
  });

  test('Hard beats an Easy-brained opponent', () {
    for (final seed in [1, 2, 3]) {
      final sim = BattleSim(data, difficulty: Difficulty.hard, seed: seed);
      final red = EnemyAi(sim);
      final blue = EnemyAi(sim, me: Side.player, level: Difficulty.easy);
      play(sim, red, 1800, other: blue);
      expect(sim.outcome, BattleOutcome.defeat, reason: 'seed $seed');
    }
  });
}
