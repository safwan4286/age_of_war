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

    test('every unit moves at one pace: idle loop 1.2 s, walk cycle 0.96 s (0.64 s mounted)', () {
      // Riders trot faster; the Cannon Crew is heavy but pushes on foot.
      const mounted = {'dinorider', 'knight'};
      for (final u in data.units) {
        final idle = u.frameCount('idle') * u.frameTime('idle', 0);
        final walk = u.frameCount('walk') * u.frameTime('walk', 0);
        expect(idle, closeTo(1.2, 0.01), reason: u.id);
        expect(walk, closeTo(mounted.contains(u.id) ? 0.64 : 0.96, 0.01), reason: u.id);
      }
    });

    test('attacks play at one pace: drawn sheets 12 fps, video clips 15 fps, inside the interval', () {
      for (final u in data.units) {
        final ft = u.frameTimes['attack'];
        expect(ft, isNotNull, reason: u.id);
        expect([0.0833, 0.0667].any((v) => (ft! - v).abs() < 1e-4), isTrue, reason: '${u.id}: $ft');
        expect(u.frameCount('attack') * ft!, lessThanOrEqualTo(u.attackEvery), reason: u.id);
      }
    });

    test('frame counts come from the data; defaults are 4/6/6/6', () {
      expect(UnitDef.defaultFrames['walk'], 6);
      expect(data.unit('dinorider').frameCount('walk'), 8);
      expect(data.unit('dinorider').frameTime('walk', 0.1), 0.08);
      expect(data.unit('chief').frameCount('walk'), 8);
      expect(data.unit('chief').frameCount('die'), 6);
      // SpriteCook walk + idle (8 frames each), earlier attack and death.
      expect(data.unit('clubman').frameCount('walk'), 8);
      expect(data.unit('clubman').frameCount('idle'), 8);
      expect(data.unit('clubman').frameTime('walk', 0.1), 0.12);
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
      expect(data.eras.map((e) => e.id), ['stone', 'medieval', 'gunpowder']);
      for (final e in data.eras) {
        expect(e.units.map((u) => u.role), UnitRole.values, reason: e.id);
        expect(e.byRole(UnitRole.ranged)!.ranged, isTrue, reason: e.id);
        // Only the Gunpowder heavy (the Cannon Crew) also shoots.
        expect(e.units.where((u) => u.ranged).map((u) => u.role),
            e.id == 'gunpowder' ? [UnitRole.ranged, UnitRole.heavy] : [UnitRole.ranged], reason: e.id);
        expect(e.units.where((u) => u.auraBonus > 0).map((u) => u.role), [UnitRole.elite], reason: e.id);
        for (final u in e.units) {
          expect(u.era, e.id, reason: u.id);
        }
      }
      expect(data.era(1).units.map((u) => u.id), ['swordsman', 'archer', 'knight', 'king']);
      expect(data.era(2).units.map((u) => u.id), ['halberdier', 'musketeer', 'cannon', 'captain']);
    });

    test('later eras are stronger: base, turret and every role', () {
      for (var i = 1; i < data.eras.length; i++) {
        final a = data.era(i - 1), b = data.era(i);
        expect(b.baseHp, greaterThan(a.baseHp), reason: b.id);
        expect(b.turret.damage / b.turret.attackEvery, greaterThan(a.turret.damage / a.turret.attackEvery),
            reason: b.id);
        for (final r in UnitRole.values) {
          final (ua, ub) = (a.byRole(r)!, b.byRole(r)!);
          // A role that starts shooting (the Cannon Crew) trades health for
          // range; the equal-gold duel test checks it still wins.
          if (ub.ranged && !ua.ranged) continue;
          expect(ub.hp, greaterThan(ua.hp), reason: '${b.id} ${r.name}');
        }
        expect(a.evolveXp, greaterThan(i == 1 ? 0 : data.era(i - 2).evolveXp), reason: a.id);
      }
      expect(data.eras.last.evolveXp, 0, reason: 'last era');
    });

    test('Gunpowder: shots, muzzles and the fort cannon', () {
      final g = data.era(2);
      expect(g.byRole(UnitRole.ranged)!.projectile, 'gunpowder_ball');
      expect(g.byRole(UnitRole.heavy)!.projectile, 'gunpowder_cannonball');
      for (final u in g.units.where((u) => u.ranged)) {
        expect(u.muzzleUp, greaterThan(0), reason: u.id);
      }
      expect(g.turret.projectile, 'gunpowder_cannonball');
      expect(g.baseArt.turretMuzzle, isNotNull);
      expect(g.baseArt.slots.length, g.turret.slots);
      expect(data.era(1).baseArt.turretMuzzle, isNull, reason: 'the ballista keeps the layout guess');
      expect(g.meteor.sprite, 'gunpowder_fireball');
      expect(g.icons['special'], 'icon_cannonbarrage');
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
