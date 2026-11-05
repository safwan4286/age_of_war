import 'package:epoch_clash/features/battle/game/world_layout.dart';
import 'package:epoch_clash/models/game_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('units.json', () {
    final data = loadData();

    test('has the Stone Age units in shop order', () {
      expect(data.era(0).units.map((u) => u.id).toList(), [
        'clubman',
        'slinger',
        'dinorider',
        'chief',
      ]);
    });

    test('frame counts come from the data; defaults are 4/6/6/6', () {
      expect(UnitDef.defaultFrames['walk'], 6);
      expect(data.unit('dinorider').frameCount('walk'), 8);
      expect(data.unit('dinorider').frameTime('walk', 0.1), 0.08);
      expect(data.unit('chief').frameCount('walk'), 8);
      expect(data.unit('chief').frameCount('die'), 6);
      expect(data.unit('clubman').frameCount('walk'), 4);
      expect(data.unit('clubman').frameTime('walk', 0.1), 0.25);
      // Walk and idle from video frames, attack and death from Gemini sheets.
      expect(data.unit('slinger').frameCount('walk'), 8);
      expect(data.unit('slinger').frameCount('attack'), 6);
      expect(data.unit('slinger').frameTime('walk', 0.1), 0.12);
    });

    test('kill rewards are about 1.3x cost', () {
      for (final u in data.units) {
        expect(u.killReward / u.cost, closeTo(1.3, 0.02), reason: u.id);
      }
    });

    test('each era has one unit per role; ranged and aura units match roles', () {
      expect(data.eras.map((e) => e.id), ['stone', 'medieval']);
      for (final e in data.eras) {
        expect(e.units.map((u) => u.role), UnitRole.values, reason: e.id);
        expect(e.units.where((u) => u.ranged).map((u) => u.role), [UnitRole.ranged], reason: e.id);
        expect(e.units.where((u) => u.auraBonus > 0).map((u) => u.role), [UnitRole.elite], reason: e.id);
        for (final u in e.units) {
          expect(u.era, e.id, reason: u.id);
        }
      }
      expect(data.era(1).units.map((u) => u.id), ['swordsman', 'archer', 'knight', 'king']);
    });

    test('later eras are stronger: base, turret and every role', () {
      final a = data.era(0), b = data.era(1);
      expect(b.baseHp, greaterThan(a.baseHp));
      expect(b.turret.damage, greaterThan(a.turret.damage));
      for (final r in UnitRole.values) {
        expect(b.byRole(r)!.hp, greaterThan(a.byRole(r)!.hp), reason: r.name);
      }
      expect(a.evolveXp, greaterThan(0));
      expect(b.evolveXp, 0, reason: 'last era');
    });

    test('base art has one ledge per turret slot; population cap is 10', () {
      expect(data.turret.slots, 3);
      expect(data.baseArt.slots.length, data.turret.slots);
      for (final (x, y) in data.baseArt.slots) {
        expect(x, inInclusiveRange(0, 1));
        expect(y, inInclusiveRange(0, 1));
      }
      expect(data.popCap, 10);
      expect(data.baseArt.turretW, inInclusiveRange(0.1, 0.4));
    });

    test('background layers cover the zoomed-out camera view', () {
      // The sky reaches above the view, the ground below it.
      expect(data.layer('sky').top, lessThanOrEqualTo(Layout.viewTop));
      final near = data.layer('near');
      expect(near.top + near.height, greaterThanOrEqualTo(Layout.viewTop + Layout.viewH));
      expect(data.laneLength, 1800);
      expect(data.layer('missing').height, 540);
    });

    test('economy, turret and meteor values', () {
      expect(data.startGold, 175);
      expect(data.queueMax, 5);
      expect(data.baseHp, 1000);
      expect(data.turret.cost, 100);
      expect(data.turret.sellBack, 50);
      expect(data.meteor.cooldown, 60);
    });

    test('AI income grows with difficulty', () {
      expect(data.aiFor(Difficulty.easy).income, 0.8);
      expect(data.aiFor(Difficulty.normal).income, 1.0);
      expect(data.aiFor(Difficulty.hard).income, 1.25);
      expect(data.aiFor(Difficulty.easy).useMeteor, isFalse);
    });
  });

  test('missing or wrong fields fall back instead of throwing', () {
    final data = GameData.fromMap({
      'lane': 'oops',
      'units': [
        {'id': 'x', 'cost': '50'},
        42,
      ],
    });
    expect(data.laneLength, 1600);
    expect(data.units.length, 1);
    expect(data.units.single.cost, 50);
    expect(data.units.single.sprite, 'x');
    expect(data.aiFor(Difficulty.hard).income, 1);
  });
}
