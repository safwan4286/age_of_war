import 'package:flame/components.dart';

import '../../../../services/sim/battle_sim.dart';
import '../world_layout.dart';

/// A meteor falling diagonally onto its impact point. It lands exactly at
/// the sim's impact time; the blast is spawned from the sim's event.
///
/// The art falls down-left (tail up-right); meteors heading right are
/// mirrored.
class MeteorView extends SpriteComponent {
  MeteorView(this.impact, this.sim, Sprite sprite)
    : super(
        sprite: sprite,
        size: Vector2(110, 110 * sprite.srcSize.y / sprite.srcSize.x),
        anchor: Anchor.center,
        priority: 30,
      );

  final MeteorImpact impact;
  final BattleSim sim;

  static const double fallTime = 0.4;
  static const double drift = 280;

  /// Meteors fall toward the side being hit.
  double get _dir => impact.caster.dir.toDouble();

  @override
  void onMount() {
    super.onMount();
    if (_dir > 0) flipHorizontally();
    update(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final t = (1 - (impact.at - sim.time) / fallTime).clamp(0.0, 1.0);
    x = impact.x - drift * _dir * (1 - t);
    y = -40 + (Layout.groundY - 10 + 40) * t;
    if (sim.time >= impact.at) removeFromParent();
  }
}

/// Explosion (square frames from fx/blast.png) that removes itself when done.
class BlastView extends SpriteAnimationComponent {
  BlastView(SpriteAnimation animation, double x)
    : super(
        animation: animation,
        removeOnFinish: true,
        size: Vector2.all(160),
        anchor: Anchor.bottomCenter,
        position: Vector2(x, Layout.groundY + 12),
        priority: 31,
      );
}
