import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../../../services/sim/battle_sim.dart';
import '../world_layout.dart';

/// Something falling from the sky onto its impact point (a meteor, or one
/// arrow of a volley). It lands exactly at the sim's impact time; the
/// blast is spawned from the sim's event.
class MeteorView extends SpriteComponent {
  MeteorView(this.impact, this.sim, Sprite sprite)
    : super(
        sprite: sprite,
        size: Vector2(impact.size, impact.size * sprite.srcSize.y / sprite.srcSize.x),
        // Arrows hang on their tip, so the tip is what lands.
        anchor: impact.style == 'arrows' ? arrowTip : Anchor.center,
        priority: 30,
      );

  final MeteorImpact impact;
  final BattleSim sim;

  /// The fire-arrow art: its tip, and the direction it points (down-left).
  static const arrowTip = Anchor(0.04, 0.96);
  static const double arrowArt = 140 * math.pi / 180;

  /// Meteors: how far sideways they slide in while falling.
  static const double drift = 280;

  /// Arrows: shot from behind the caster's line, arcing over and down.
  static const double arrowRun = 300;
  static const double arrowTop = -200;

  bool get _arrow => impact.style == 'arrows';

  /// Falls toward the side being hit.
  double get _dir => impact.caster.dir.toDouble();

  @override
  void onMount() {
    super.onMount();
    // Meteor art falls down-left; mirrored when heading right. Arrows are
    // rotated to their path instead.
    if (!_arrow && _dir > 0) flipHorizontally();
    update(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final t = (1 - (impact.at - sim.time) / impact.fallTime).clamp(0.0, 1.0);
    if (_arrow) {
      _flyArrow(t);
    } else {
      x = impact.x - drift * _dir * (1 - t);
      y = -40 + (Layout.groundY - 10 + 40) * t;
    }
    if (sim.time >= impact.at) {
      if (_arrow) parent?.add(StuckArrow(sprite!, size, Vector2(x, y), angle));
      removeFromParent();
    }
  }

  /// Along a falling curve: steady sideways, speeding up downwards, the
  /// arrow always pointing where it is going.
  void _flyArrow(double t) {
    const k = 1.6; // how much it speeds up as it drops
    final endY = Layout.groundY + 4;
    x = impact.x - _dir * arrowRun * (1 - t);
    y = arrowTop + (endY - arrowTop) * math.pow(t, k);
    final vx = _dir * arrowRun;
    final vy = (endY - arrowTop) * k * math.pow(math.max(t, 0.05), k - 1);
    angle = math.atan2(vy, vx) - arrowArt;
  }
}

/// An arrow of the volley left standing in the ground; fades away.
class StuckArrow extends SpriteComponent {
  StuckArrow(Sprite sprite, Vector2 size, Vector2 position, double angle)
    : super(
        sprite: sprite,
        size: size,
        position: position,
        angle: angle,
        anchor: MeteorView.arrowTip,
        // Behind the units: they walk past it.
        priority: 9,
      );

  static const double life = 1.6;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    // A small quiver on impact, then still; fades in the last half second.
    final wobble = _age < 0.25 ? math.sin(_age * 60) * 0.06 * (1 - _age / 0.25) : 0.0;
    transform.angle += wobble - (_lastWobble);
    _lastWobble = wobble;
    opacity = ((life - _age) / 0.5).clamp(0.0, 1.0);
    if (_age >= life) removeFromParent();
  }

  double _lastWobble = 0;
}

/// An impact (square frames side by side) that removes itself when done.
class BlastView extends SpriteAnimationComponent {
  BlastView(SpriteAnimation animation, double x, {double size = 160})
    : super(
        animation: animation,
        removeOnFinish: true,
        size: Vector2.all(size),
        anchor: Anchor.bottomCenter,
        position: Vector2(x, Layout.groundY + size * 0.075),
        priority: 31,
      );
}
