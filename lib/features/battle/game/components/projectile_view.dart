import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../../../resources/assets.dart';
import '../../../../services/sim/battle_sim.dart';
import '../world_layout.dart';

/// A shot flying along an arc: stones and rocks tumble, arrows and bolts
/// point along their path. The sim only tracks x; the arc is drawn here.
class ProjectileView extends SpriteComponent {
  /// [launch]: where the shot visibly leaves from (a turret on its
  /// ledge), blending into the sim's x as it flies.
  ProjectileView(this.p, Sprite sprite, {Vector2? launch})
    : _startY = launch?.y ?? Layout.slingY,
      _launchOffset = launch == null ? 0 : launch.x - p.startX,
      _spins = Img.spinning.contains(p.sprite),
      super(
        sprite: sprite,
        size: Vector2(
          Img.fxWidth(p.sprite),
          Img.fxWidth(p.sprite) * sprite.srcSize.y / sprite.srcSize.x,
        ),
        anchor: Anchor.center,
        priority: 20,
      );

  final SimProjectile p;
  final double _startY;
  final double _launchOffset;
  final bool _spins;

  /// Bolts fly flatter than thrown rocks.
  double get _arc {
    final k = _spins ? 0.22 : 0.12;
    return ((p.targetX - p.startX).abs() * k).clamp(_spins ? 16.0 : 8.0, 110.0).toDouble();
  }

  Vector2 _at(double t) => Vector2(
    p.x + _launchOffset * (1 - t),
    _startY + (Layout.hitY - _startY) * t - math.sin(math.pi * t) * _arc,
  );

  @override
  void onMount() {
    super.onMount();
    update(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final t = p.progress;
    position = _at(t);
    if (_spins) {
      angle += dt * 12 * p.side.dir;
      return;
    }
    // Point along the flight: the slope of the arc at t.
    final dx = (p.targetX - p.startX) - _launchOffset;
    final dy = (Layout.hitY - _startY) - math.cos(math.pi * t) * math.pi * _arc;
    if (dx.abs() + dy.abs() > 0.01) angle = math.atan2(dy, dx);
  }
}
