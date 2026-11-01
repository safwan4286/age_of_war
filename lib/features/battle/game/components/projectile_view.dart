import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../../../services/sim/battle_sim.dart';
import '../world_layout.dart';

/// A stone (slinger) or rock (turret) flying along an arc. The sim only
/// tracks x; the arc is drawn here.
class ProjectileView extends SpriteComponent {
  /// [launch]: where the shot visibly leaves from (a catapult on its
  /// ledge), blending into the sim's x as it flies.
  ProjectileView(this.p, Sprite sprite, {Vector2? launch})
    : _startY = launch?.y ?? Layout.slingY,
      _launchOffset = launch == null ? 0 : launch.x - p.startX,
      super(
        sprite: sprite,
        size: Vector2.all(p.kind == ProjectileKind.rock ? 22 : 12),
        anchor: Anchor.center,
        priority: 20,
      );

  final SimProjectile p;
  final double _startY;
  final double _launchOffset;

  double get _arc =>
      ((p.targetX - p.startX).abs() * 0.22).clamp(16.0, 110.0).toDouble();

  @override
  void update(double dt) {
    super.update(dt);
    final t = p.progress;
    x = p.x + _launchOffset * (1 - t);
    y = _startY + (Layout.hitY - _startY) * t - math.sin(math.pi * t) * _arc;
    angle += dt * 12 * p.side.dir;
  }
}
