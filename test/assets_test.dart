import 'dart:io';

import 'package:epoch_clash/resources/assets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final data = loadData();

  test('every image a battle loads exists, for every age', () {
    final missing = Img.all(data).where((p) => !File('assets/images/$p').existsSync()).toList();
    expect(missing, isEmpty);
  });

  test('every age has its HUD icons', () {
    for (final e in data.eras) {
      for (final path in [UiImg.special(e), UiImg.evolve(e), UiImg.turret(e)]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      for (final u in e.units) {
        expect(File(UiImg.unitCard(u.sprite)).existsSync(), isTrue, reason: u.id);
      }
    }
  });

  test('every unit strip holds its frames (one row, or a grid past 4096 px)', () {
    for (final e in data.eras) {
      for (final u in e.units) {
        for (final anim in Img.unitAnims) {
          final path = 'assets/images/${Img.unit(u, anim)}';
          final (w, h) = _pngSize(path);
          final n = u.frameCount(anim);
          final perRow = w ~/ u.frameW;
          final why = '$path: ${w}x$h for $n frames of ${u.frameW}x${u.frameH}';
          expect(w % u.frameW, 0, reason: why);
          expect(w, lessThanOrEqualTo(4096), reason: why);
          expect(perRow * (h ~/ u.frameH), greaterThanOrEqualTo(n), reason: why);
          expect(h % u.frameH, 0, reason: why);
        }
      }
    }
  });

  test('art is named by age', () {
    final knight = data.unit('knight');
    expect(Img.unit(knight, 'walk', red: true), 'units/medieval_knight_walk_red.png');
    expect(Img.base('medieval'), 'bases/medieval_base.png');
    expect(Img.era(data.era(1)), contains('fx/medieval_bolt.png'));
    expect(Img.era(data.era(1)), contains('fx/medieval_blast.png'));
    expect(Img.era(data.era(2)), containsAll(['fx/gunpowder_ball.png', 'fx/gunpowder_cannonball.png',
        'fx/gunpowder_fireball.png', 'fx/gunpowder_blast.png', 'bases/gunpowder_turret_fire_red.png']));
    // Every gunpowder shot gets a muzzle flash; a musket ball is tiny.
    expect(Img.firearms.keys, containsAll(['gunpowder_ball', 'gunpowder_cannonball']));
    expect(Img.fxWidth('gunpowder_ball'), lessThan(Img.fxWidth('gunpowder_cannonball')));
    expect(Img.era(data.era(3)), containsAll(['fx/modern_bullet.png', 'fx/modern_shell.png', 'fx/modern_rocket.png',
        'fx/modern_bomb.png', 'fx/modern_blast.png', 'bases/modern_turret_fire_red.png', 'bg/modern_sky.png']));
    expect(Img.firearms.keys, containsAll(['modern_bullet', 'modern_shell', 'modern_rocket']));
  });
}

/// Width and height from a PNG's header.
(int, int) _pngSize(String path) {
  final b = File(path).readAsBytesSync();
  int be(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (be(16), be(20));
}
