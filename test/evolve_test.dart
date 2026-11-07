import 'package:epoch_clash/models/game_data.dart';
import 'package:epoch_clash/services/sim/battle_sim.dart';
import 'package:epoch_clash/services/sim/enemy_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final data = loadData();
  BattleSim fresh() => BattleSim(data);

  test('evolving needs the XP and stops at the last era', () {
    final sim = fresh();
    final p = sim[Side.player];
    expect(sim.evolve(Side.player), isFalse);
    p.xp = data.era(0).evolveXp;
    expect(sim.canEvolve, isTrue);
    expect(sim.evolve(Side.player), isTrue);
    expect(p.era, 1);
    expect(sim.eraOf(Side.player).id, 'medieval');
    // XP is a running total: the next age needs more of it.
    p.xp = data.era(1).evolveXp - 1;
    expect(sim.canEvolve, isFalse);
    expect(sim.evolve(Side.player), isFalse);
  });

  test('the base gains the difference in full health', () {
    final sim = fresh();
    final p = sim[Side.player];
    p.baseHp = 600;
    p.xp = data.era(0).evolveXp;
    sim.evolve(Side.player);
    expect(p.baseHp, 600 + data.era(1).baseHp - data.era(0).baseHp);
    expect(sim.maxHp(Side.player), data.era(1).baseHp);
  });

  test('only the current era is for sale', () {
    final sim = fresh();
    sim[Side.player].gold = 10000;
    expect(sim.queueUnit(Side.player, 'swordsman'), isFalse);
    expect(sim.queueUnit(Side.player, 'clubman'), isTrue);
    sim[Side.player].xp = data.era(0).evolveXp;
    sim.evolve(Side.player);
    expect(sim.queueUnit(Side.player, 'clubman'), isFalse);
    expect(sim.queueUnit(Side.player, 'swordsman'), isTrue);
  });

  test('turrets and the special follow the era', () {
    final sim = fresh();
    sim[Side.player].gold = 10000;
    sim.buyTurret(Side.player, 0);
    expect(sim.turretDamage(Side.player), data.era(0).turret.damage);
    sim[Side.player].xp = data.era(0).evolveXp;
    sim.evolve(Side.player);
    expect(sim.turretDamage(Side.player), data.era(1).turret.damage);
    final before = sim[Side.player].gold;
    sim.sellTurret(Side.player, 0);
    expect(sim[Side.player].gold - before, data.era(1).turret.sellBack);
    sim[Side.player].meteorCharge = data.era(1).meteor.cooldown;
    place(sim, Side.enemy, 'clubman', 900);
    expect(sim.castMeteor(Side.player), isTrue);
    expect(sim.meteors.length, data.era(1).meteor.count);
    expect(sim.meteors.first.sprite, data.era(1).meteor.sprite);
    // Arrow Rain: a volley in the air for fallTime before the first lands.
    expect(sim.meteors.first.style, 'arrows');
    expect(sim.meteors.first.at - sim.time, closeTo(data.era(1).meteor.fallTime, 1e-9));
  });

  test('ranged shots and turret shots carry their era art', () {
    final sim = fresh();
    sim[Side.player].xp = data.era(0).evolveXp;
    sim.evolve(Side.player);
    sim[Side.player].gold = 10000;
    sim.buyTurret(Side.player, 0);
    place(sim, Side.player, 'archer', 500);
    place(sim, Side.enemy, 'clubman', 650);
    run(sim, 3);
    final sprites = <String>{};
    run(sim, 2, each: () => sprites.addAll(sim.projectiles.map((p) => p.sprite)));
    expect(sprites, contains('medieval_arrow'));
  });

  test('the ages run Stone, Medieval, Gunpowder, Modern; Modern is the last for now', () {
    final sim = fresh();
    final p = sim[Side.player];
    for (final (i, id) in [(0, 'medieval'), (1, 'gunpowder'), (2, 'modern')]) {
      p.xp = data.era(i).evolveXp;
      expect(sim.evolve(Side.player), isTrue, reason: id);
      expect(sim.eraOf(Side.player).id, id);
      expect(sim.maxHp(Side.player), data.era(i + 1).baseHp);
    }
    p.xp = 1 << 30;
    expect(sim.evolve(Side.player), isFalse, reason: 'no age after Modern yet');
  });

  test('Modern shots: bullets, tank shells and rockets from the pod', () {
    final sim = fresh();
    for (final i in [0, 1, 2]) {
      sim[Side.player].xp = data.era(i).evolveXp;
      sim.evolve(Side.player);
    }
    sim[Side.player].gold = 100000;
    sim.buyTurret(Side.player, 0);
    place(sim, Side.player, 'machinegunner', 500);
    place(sim, Side.player, 'tank', 440);
    place(sim, Side.enemy, 'clubman', 720);
    place(sim, Side.enemy, 'clubman', 740);
    // One that slipped through, in the rocket pod's reach.
    place(sim, Side.enemy, 'chief', 380);
    final sprites = <String>{};
    run(sim, 6, each: () => sprites.addAll(sim.projectiles.where((p) => p.side == Side.player).map((p) => p.sprite)));
    expect(sprites, containsAll(['modern_bullet', 'modern_shell', 'modern_rocket']));
  });

  test('Gunpowder shots: musket balls, cannonballs from the crew and the fort', () {
    final sim = fresh();
    for (final i in [0, 1]) {
      sim[Side.player].xp = data.era(i).evolveXp;
      sim.evolve(Side.player);
    }
    sim[Side.player].gold = 100000;
    sim.buyTurret(Side.player, 0);
    place(sim, Side.player, 'musketeer', 500);
    place(sim, Side.player, 'cannon', 470);
    place(sim, Side.enemy, 'clubman', 700);
    place(sim, Side.enemy, 'clubman', 720);
    final sprites = <String>{};
    run(sim, 6, each: () => sprites.addAll(sim.projectiles.where((p) => p.side == Side.player).map((p) => p.sprite)));
    expect(sprites, containsAll(['gunpowder_ball', 'gunpowder_cannonball']));
  });

  test('each age beats the one before, role for role, at equal gold', () {
    for (var e = 1; e < data.eras.length; e++) {
      for (final r in UnitRole.values) {
        var edge = 0.0;
        // Both ways round, so which side starts where doesn't matter.
        for (final newSide in Side.values) {
          final oldSide = newSide == Side.player ? Side.enemy : Side.player;
          final sim = fresh();
          for (var i = 0; i < e; i++) {
            sim[newSide].xp = data.era(i).evolveXp;
            sim.evolve(newSide);
            if (i < e - 1) {
              sim[oldSide].xp = data.era(i).evolveXp;
              sim.evolve(oldSide);
            }
          }
          final a = data.era(e).byRole(r)!, b = data.era(e - 1).byRole(r)!;
          final budget = a.cost * 4.0;
          double x(Side s, int i) => s == Side.player ? 800 - i * 22.0 : 1000 + i * 22.0;
          final mine = [for (var i = 0; i < budget ~/ a.cost; i++) place(sim, newSide, a.id, x(newSide, i))];
          final theirs = [for (var i = 0; i < budget ~/ b.cost; i++) place(sim, oldSide, b.id, x(oldSide, i))];
          double value(List<SimUnit> us) =>
              us.where((u) => u.alive).fold(0.0, (v, u) => v + u.def.cost * u.hp / u.def.hp);
          for (var t = 0; t < 4000 && value(mine) > 0 && value(theirs) > 0; t++) {
            sim.step(0.05);
          }
          edge += (value(mine) - value(theirs)) / budget / 2;
        }
        expect(edge, greaterThan(0.25), reason: '${data.era(e).id} ${r.name}');
      }
    }
  });

  test('the AI evolves and then trains the new roster by role', () {
    final sim = BattleSim(data, difficulty: Difficulty.normal);
    final ai = EnemyAi(sim);
    sim[Side.enemy].xp = data.era(0).evolveXp;
    ai.think();
    expect(sim[Side.enemy].era, 1);
    sim[Side.enemy].gold = 120;
    final pick = ai.choose();
    expect(pick, isNotNull);
    expect(data.unit(pick!).era, 'medieval');
  });
}
