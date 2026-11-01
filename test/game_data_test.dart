import 'package:epoch_clash/models/game_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('units.json', () {
    final data = loadData();

    test('has the Stone Age units in shop order', () {
      expect(data.units.map((u) => u.id).toList(), [
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
      // Built from the 3-sheet layout: 4 of the 8 walk poses, 6-frame attack.
      expect(data.unit('slinger').frameCount('walk'), 4);
      expect(data.unit('slinger').frameCount('attack'), 6);
      expect(data.unit('slinger').frameTime('walk', 0.1), 0.22);
    });

    test('kill rewards are about 1.3x cost', () {
      for (final u in data.units) {
        expect(u.killReward / u.cost, closeTo(1.3, 0.02), reason: u.id);
      }
    });

    test('only the slinger is ranged and only the chief has an aura', () {
      expect(data.units.where((u) => u.ranged).map((u) => u.id), ['slinger']);
      expect(data.units.where((u) => u.auraBonus > 0).map((u) => u.id), [
        'chief',
      ]);
    });

    test('base art has one ledge per turret slot; population cap is 10', () {
      expect(data.turret.slots, 3);
      expect(data.baseArt.slots.length, data.turret.slots);
      for (final (x, y) in data.baseArt.slots) {
        expect(x, inInclusiveRange(0, 1));
        expect(y, inInclusiveRange(0, 1));
      }
      expect(data.popCap, 10);
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
