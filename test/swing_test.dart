import 'package:epoch_clash/models/game_data.dart';
import 'package:epoch_clash/services/sim/swing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

UnitDef _unit({double every = 1.6, int frames = 19, double? ft, int impact = -1}) => UnitDef.fromMap({
  'id': 'x',
  'attackEvery': every,
  'frames': {'attack': frames},
  'frameTimes': {'attack': ?ft},
  'impactFrame': impact,
});

void main() {
  test('the impact frame shows exactly when the blow lands', () {
    final s = Swing(_unit(ft: 0.08, impact: 8));
    expect(s.frameAt(toHit: 0), 8);
    expect(s.frameAt(toHit: 0.0001), 7);
    expect(s.frameAt(toHit: 8 * 0.08), 0);
  });

  test('a short swing holds the ready pose between blows', () {
    final s = Swing(_unit(ft: 0.08, impact: 8)); // 1.52 s swing, 1.6 s apart
    expect(s.duration, closeTo(1.52, 1e-9));
    expect(s.frameAt(toHit: 0.75, sinceHit: 0.85), 18); // follow-through, last frame
    expect(s.frameAt(toHit: 0.68, sinceHit: 0.92), 0); // waiting
    expect(s.frameAt(toHit: 1.0), 0); // before the first blow
  });

  test('a swing longer than the interval is sped up to fit', () {
    final s = Swing(_unit(every: 1.0, ft: 0.1, impact: 8));
    expect(s.duration, closeTo(1.0, 1e-9));
    expect(s.frameAt(toHit: 0), 8);
  });

  test('old units without their own pace loop exactly as before', () {
    final s = Swing(_unit(every: 1.0, frames: 8));
    expect(s.impactAt, closeTo(0.5, 1e-9)); // frame 4 of 8
    expect(s.frameAt(toHit: 0.5), 0);
    expect(s.frameAt(toHit: 0), 4);
    expect(s.frameAt(toHit: 0.9, sinceHit: 0.1), 4 + 0); // 0.6 s in
    expect(s.frameAt(toHit: 0.6, sinceHit: 0.4), 7);
  });

  test('the Medieval Swordsman: full swing fits, same damage per second', () {
    final sw = loadData().unit('swordsman');
    final s = Swing(sw);
    expect(s.duration, lessThanOrEqualTo(sw.attackEvery));
    expect(sw.damage / sw.attackEvery, closeTo(30, 0.01));
  });
}
