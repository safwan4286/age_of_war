import 'dart:io';

import 'package:epoch_clash/services/audio/sound_cues.dart';
import 'package:epoch_clash/services/sim/battle_sim.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final data = loadData();

  test('every sound effect has a file', () {
    for (final s in Sfx.values) {
      expect(File('assets/audio/${s.file}').existsSync(), isTrue, reason: s.file);
    }
    expect(Sfx.swingHeavy.file, 'sfx/swing_heavy.wav');
  });

  test('melee swings, shots and hits make their sounds; the enemy is quieter', () {
    final sim = BattleSim(data);
    place(sim, Side.player, 'clubman', 600);
    place(sim, Side.player, 'slinger', 520);
    place(sim, Side.enemy, 'dinorider', 640);
    final cues = <SoundCue>{};
    run(sim, 4, each: () {
      for (final e in sim.drainEvents()) {
        cues.addAll(cuesFor(e, sim));
      }
    });
    final kinds = cues.map((c) => c.sfx).toSet();
    expect(kinds, containsAll([Sfx.swingLight, Sfx.swingHeavy, Sfx.throwStone, Sfx.hit]));
    expect(cues, contains(const SoundCue(Sfx.swingHeavy, 0.7)));
    expect(cues, contains(const SoundCue(Sfx.swingLight)));
  });

  test('specials: meteor in the Stone Age, a volley in the Medieval', () {
    final sim = BattleSim(data);
    place(sim, Side.enemy, 'clubman', 900);
    sim[Side.player].meteorCharge = 999;
    sim.castMeteor(Side.player);
    final stone = sim.drainEvents().expand((e) => cuesFor(e, sim)).map((c) => c.sfx);
    expect(stone, contains(Sfx.meteorCast));

    final med = BattleSim(data);
    med[Side.player].xp = data.era(0).evolveXp;
    med.evolve(Side.player);
    place(med, Side.enemy, 'clubman', 900);
    med[Side.player].meteorCharge = 999;
    med.castMeteor(Side.player);
    final cues = <Sfx>[];
    run(med, 3, each: () => cues.addAll(med.drainEvents().expand((e) => cuesFor(e, med)).map((c) => c.sfx)));
    expect(cues, containsAll([Sfx.evolve, Sfx.volleyCast, Sfx.arrowImpact]));
    expect(cues, isNot(contains(Sfx.meteorImpact)));
  });

  test('turret shots: catapult rocks, ballista bolts and fort cannonballs', () {
    for (final (era, sfx) in [(0, Sfx.catapult), (1, Sfx.ballista), (2, Sfx.cannon)]) {
      final sim = BattleSim(data);
      for (var i = 0; i < era; i++) {
        sim[Side.player].xp = data.era(i).evolveXp;
        sim.evolve(Side.player);
      }
      sim[Side.player].gold = 9999;
      sim.buyTurret(Side.player, 0);
      place(sim, Side.enemy, 'clubman', 300);
      final cues = <Sfx>[];
      run(sim, 4, each: () => cues.addAll(sim.drainEvents().expand((e) => cuesFor(e, sim)).map((c) => c.sfx)));
      expect(cues, containsAll([Sfx.build, sfx]), reason: 'era $era');
    }
  });

  test('Gunpowder: muskets crack, the Cannon Crew booms', () {
    final sim = BattleSim(data);
    for (final i in [0, 1]) {
      sim[Side.player].xp = data.era(i).evolveXp;
      sim.evolve(Side.player);
    }
    place(sim, Side.player, 'musketeer', 500);
    place(sim, Side.player, 'cannon', 470);
    place(sim, Side.enemy, 'clubman', 700);
    final cues = <Sfx>[];
    run(sim, 6, each: () => cues.addAll(sim.drainEvents().expand((e) => cuesFor(e, sim)).map((c) => c.sfx)));
    expect(cues, containsAll([Sfx.musket, Sfx.cannon]));
    expect(cues, isNot(contains(Sfx.throwStone)));
  });
}
