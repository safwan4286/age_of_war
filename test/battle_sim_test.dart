import 'package:epoch_clash/models/game_data.dart';
import 'package:epoch_clash/services/sim/battle_sim.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final data = loadData();
  BattleSim fresh({Difficulty d = Difficulty.normal}) =>
      BattleSim(data, difficulty: d);

  group('economy', () {
    test('both sides start with gold and full bases', () {
      final sim = fresh();
      for (final s in Side.values) {
        expect(sim[s].gold, 175);
        expect(sim[s].baseHp, 1000);
      }
    });

    test('gold trickles in, scaled for the enemy by difficulty', () {
      final sim = fresh(d: Difficulty.hard);
      run(sim, 10);
      expect(sim[Side.player].gold, closeTo(175 + 20, 0.01));
      expect(sim[Side.enemy].gold, closeTo(175 + 25, 0.01));
    });

    test('queueing pays up front and respects gold and the queue cap', () {
      final sim = fresh();
      expect(sim.queueUnit(Side.player, 'clubman'), isTrue);
      expect(sim[Side.player].gold, 125);
      expect(sim.queueUnit(Side.player, 'chief'), isFalse);
      sim[Side.player].gold = 10000;
      for (var i = 0; i < 4; i++) {
        expect(sim.queueUnit(Side.player, 'clubman'), isTrue);
      }
      expect(sim.queueUnit(Side.player, 'clubman'), isFalse);
      expect(sim[Side.player].queue.length, 5);
    });
  });

  group('training', () {
    test('a unit spawns at the base front after its train time', () {
      final sim = fresh();
      sim.queueUnit(Side.player, 'clubman');
      run(sim, 1.4);
      expect(sim.units, isEmpty);
      run(sim, 0.2);
      expect(sim.units.length, 1);
      expect(sim.units.single.side, Side.player);
    });

    test('enemy units spawn at the right-hand front and walk left', () {
      final sim = fresh();
      sim.queueUnit(Side.enemy, 'clubman');
      run(sim, 1.6);
      final u = sim.units.single;
      expect(u.x, closeTo(data.laneLength - data.baseWidth, 10));
      final before = u.x;
      run(sim, 1);
      expect(u.x, lessThan(before));
    });

    test('the next unit waits for room at the spawn point', () {
      final sim = fresh();
      sim[Side.player].gold = 1000;
      sim.queueUnit(Side.player, 'clubman');
      sim.queueUnit(Side.player, 'clubman');
      // Second unit is trained 3.0 s in; the first has moved 60 px by
      // then, which is enough room (spawnGap 26 + half its width 17).
      run(sim, 3.1);
      expect(sim.units.length, 2);
      final a = sim.units[0], b = sim.units[1];
      expect(a.x - b.x, greaterThan(data.spawnGap));
    });
  });

  group('combat', () {
    test('two clubmen meet; the winner gets gold and XP', () {
      final sim = fresh();
      sim.queueUnit(Side.player, 'clubman');
      sim.queueUnit(Side.enemy, 'clubman');
      final goldBefore = sim[Side.player].gold;
      run(sim, 40);
      final kills = sim[Side.player].kills + sim[Side.enemy].kills;
      expect(kills, 1);
      // Ties go to the player: the player's units act first each tick.
      expect(sim[Side.player].kills, 1);
      expect(sim[Side.player].xp, 40);
      expect(sim[Side.player].gold, greaterThan(goldBefore + 65));
    });

    test('dead units play their death, then leave the lane', () {
      final sim = fresh();
      final e = place(sim, Side.enemy, 'clubman', 800);
      place(sim, Side.player, 'dinorider', 760);
      var sawDying = false;
      run(sim, 6, each: () {
        if (e.state == UnitState.dying) sawDying = true;
      });
      expect(sawDying, isTrue);
      expect(sim.units.contains(e), isFalse);
    });

    test('slingers shoot projectiles that do damage on arrival', () {
      final sim = fresh();
      final e = place(sim, Side.enemy, 'chief', 900);
      place(sim, Side.player, 'slinger', 760);
      sim.drainEvents();
      run(sim, 1.5);
      final events = sim.drainEvents();
      expect(events.any((ev) => ev.type == SimEventType.projectile), isTrue);
      expect(e.hp, lessThan(e.def.hp));
    });

    test('melee blocks: a slinger stays behind its clubman', () {
      final sim = fresh();
      final club = place(sim, Side.player, 'clubman', 500);
      final sling = place(sim, Side.player, 'slinger', 440);
      place(sim, Side.enemy, 'chief', 560);
      run(sim, 3);
      expect(sling.x, lessThan(club.x));
    });

    test('a chief makes nearby allies hit 10% harder', () {
      final sim = fresh();
      final club = place(sim, Side.player, 'clubman', 700);
      place(sim, Side.player, 'chief', 640);
      place(sim, Side.enemy, 'dinorider', 760);
      sim.drainEvents();
      run(sim, 2);
      final hits = sim
          .drainEvents()
          .where((e) => e.type == SimEventType.hit && e.side == Side.enemy)
          .map((e) => e.amount);
      expect(hits, contains(closeTo(club.def.damage * 1.1, 0.001)));
    });

    test('units that reach the enemy base damage it', () {
      final sim = fresh();
      place(sim, Side.player, 'clubman', data.laneLength - data.baseWidth - 40);
      run(sim, 5);
      expect(sim[Side.enemy].baseHp, lessThan(1000));
    });
  });

  group('turrets', () {
    test('three ledges: build fills the first empty one, a fourth fails', () {
      final sim = fresh();
      sim[Side.player].gold = 1000;
      expect(sim.buyTurret(Side.player), isTrue);
      expect(sim.buyTurret(Side.player, 2), isTrue);
      expect(sim[Side.player].turrets, [true, false, true]);
      expect(sim.buyTurret(Side.player, 2), isFalse);
      expect(sim.buyTurret(Side.player), isTrue);
      expect(sim.buyTurret(Side.player), isFalse);
      expect(sim[Side.player].gold, 1000 - 3 * data.turret.cost);
    });

    test('each turret shoots; selling a ledge pays half back', () {
      final sim = fresh();
      sim[Side.player].gold = 1000;
      sim.buyTurret(Side.player, 0);
      sim.buyTurret(Side.player, 1);
      final e = place(sim, Side.enemy, 'chief', data.baseWidth + 200);
      e.hp = 100000;
      sim.drainEvents();
      sim.step(0.05);
      final shots = sim.projectiles.where((p) => p.kind == ProjectileKind.rock);
      expect(shots.map((p) => p.slot).toSet(), {0, 1});
      final g = sim[Side.player].gold;
      expect(sim.sellTurret(Side.player, 1), isTrue);
      expect(sim[Side.player].gold, g + data.turret.sellBack);
      expect(sim[Side.player].turrets, [true, false, false]);
      expect(sim.sellTurret(Side.player, 1), isFalse);
    });

    test('does not fire at enemies out of range', () {
      final sim = fresh();
      sim.buyTurret(Side.player);
      final e = place(sim, Side.enemy, 'chief', 1200);
      e.state = UnitState.idle;
      sim.drainEvents();
      sim.step(0.05);
      expect(
        sim.drainEvents().where((ev) => ev.type == SimEventType.projectile),
        isEmpty,
      );
    });
  });

  test('population cap: alive + training never passes 10', () {
    final sim = fresh();
    for (var i = 0; i < 8; i++) {
      place(sim, Side.player, 'clubman', 300 + i * 40.0);
    }
    sim[Side.player].gold = 1000;
    expect(sim.queueUnit(Side.player, 'clubman'), isTrue);
    expect(sim.queueUnit(Side.player, 'clubman'), isTrue);
    expect(sim.population(Side.player), 10);
    expect(sim.queueUnit(Side.player, 'clubman'), isFalse);
  });

  group('meteor', () {
    test('charges over 60 s, then rains on the other army only', () {
      final sim = fresh();
      expect(sim.castMeteor(Side.player), isFalse);
      run(sim, 61);
      expect(sim.meteorReady(Side.player), isTrue);
      final foe = place(sim, Side.enemy, 'chief', 1000);
      final mine = place(sim, Side.player, 'chief', 980);
      foe.hp = mine.hp = 100000;
      expect(sim.castMeteor(Side.player), isTrue);
      expect(sim.meteorReady(Side.player), isFalse);
      final (lo, hi) = sim.meteorZone(Side.player);
      for (final m in sim.meteors) {
        expect(m.x, greaterThanOrEqualTo(lo));
        expect(m.x, lessThan(hi + 0.001));
      }
      // Hold both still so only the meteors change their hp... and keep
      // them out of each other's reach.
      run(sim, 3, each: () {
        foe.x = 1000;
        mine.x = 700;
        foe.state = mine.state = UnitState.idle;
      });
      expect(mine.hp, 100000);
      expect(foe.hp, lessThan(100000));
      expect(sim.meteors, isEmpty);
    });

    test('with no army to aim at, rocks fall on the other half', () {
      final sim = fresh();
      final (lo, hi) = sim.meteorZone(Side.player);
      expect(lo, data.laneLength / 2);
      expect(hi, data.laneLength - data.baseWidth);
    });

    test('every rock that lands on a unit hits it', () {
      final sim = fresh();
      run(sim, 61);
      final e = place(sim, Side.enemy, 'chief', 1000);
      e.hp = 100000;
      sim.castMeteor(Side.player);
      // Re-aim every rock at the unit.
      for (var i = 0; i < sim.meteors.length; i++) {
        final m = sim.meteors[i];
        sim.meteors[i] = MeteorImpact(caster: m.caster, x: 1000, at: m.at);
      }
      run(sim, 3, each: () => e.x = 1000);
      expect(e.hp, 100000 - data.meteor.count * data.meteor.damage);
    });
  });

  group('result', () {
    test('destroying the enemy base wins; stars follow base health', () {
      for (final (hp, stars) in [(900.0, 3), (500.0, 2), (100.0, 1)]) {
        final sim = fresh();
        sim[Side.player].baseHp = hp;
        sim[Side.enemy].baseHp = 0.5;
        place(sim, Side.player, 'clubman', data.laneLength - data.baseWidth - 15);
        run(sim, 3);
        expect(sim.outcome, BattleOutcome.victory);
        expect(sim.stars, stars, reason: 'base at $hp');
      }
    });

    test('losing your base is a defeat with no stars', () {
      final sim = fresh();
      sim[Side.player].baseHp = 0.5;
      place(sim, Side.enemy, 'clubman', data.baseWidth + 15);
      run(sim, 3);
      expect(sim.outcome, BattleOutcome.defeat);
      expect(sim.stars, 0);
      expect(sim.queueUnit(Side.player, 'clubman'), isFalse);
    });

    test('evolve unlocks at 4000 XP', () {
      final sim = fresh();
      expect(sim.canEvolve, isFalse);
      sim[Side.player].xp = 4000;
      expect(sim.canEvolve, isTrue);
    });
  });

  test('the same seed plays out the same battle', () {
    List<double> play() {
      final sim = BattleSim(data, seed: 3);
      run(sim, 60);
      sim[Side.player].gold = sim[Side.enemy].gold = 2000;
      for (final id in ['clubman', 'slinger', 'dinorider']) {
        sim.queueUnit(Side.player, id);
        sim.queueUnit(Side.enemy, id);
      }
      sim.castMeteor(Side.player);
      run(sim, 60);
      return [
        for (final u in sim.units) u.x,
        sim[Side.player].baseHp,
        sim[Side.enemy].baseHp,
      ];
    }

    expect(play(), play());
  });
}
