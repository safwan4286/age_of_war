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
    p.xp = 999999;
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
