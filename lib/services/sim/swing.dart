import 'dart:math' as math;

import '../../models/game_data.dart';
import 'battle_sim.dart';

/// Which attack frame a unit shows, so the art's impact frame is on
/// screen exactly when the sim lands the blow.
///
/// The swing plays at the art's own pace (`frameTimes.attack`). If it is
/// shorter than the time between blows, the unit holds its ready pose
/// (frame 0) in between; if longer, it is sped up to fit. Without its own
/// pace the swing fills the whole interval (the old behaviour).
class Swing {
  Swing(UnitDef def) : frames = math.max(1, def.frameCount('attack')) {
    var ft = def.frameTimes['attack'] ?? def.attackEvery / frames;
    if (ft * frames > def.attackEvery) ft = def.attackEvery / frames;
    frameTime = ft;
    final impact = def.impactFrame >= 0
        ? math.min(def.impactFrame, frames - 1)
        : (frames * BattleSim.windup).round();
    impactAt = impact * ft;
  }

  final int frames;
  late final double frameTime;

  /// Seconds from the start of the swing to the blow.
  late final double impactAt;

  double get duration => frames * frameTime;

  /// [toHit]: seconds until the next blow (the sim's cooldown).
  /// [sinceHit]: seconds since the last blow, null before the first one.
  int frameAt({required double toHit, double? sinceHit}) {
    double t;
    if (toHit <= impactAt) {
      t = impactAt - toHit; // swinging into the next blow
    } else if (sinceHit != null && impactAt + sinceHit < duration) {
      t = impactAt + sinceHit; // follow-through after the last one
    } else {
      return 0; // ready pose
    }
    return (t / frameTime).floor().clamp(0, frames - 1);
  }
}
