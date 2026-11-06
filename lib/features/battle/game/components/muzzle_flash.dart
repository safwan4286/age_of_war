import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// A gunshot at the muzzle: a bright star-shaped flash for a blink, then
/// a few grey smoke puffs that swell, drift up and fade. Drawn in code
/// (no art), sized by [power] (1 = a musket) and facing [dir] (+1 right).
class MuzzleFlash extends PositionComponent {
  MuzzleFlash(Vector2 at, {required this.dir, this.power = 1})
    : super(position: at, priority: 21);

  final double dir;
  /// How big the gun is: 1 = a musket.
  final double power;

  static const double flashTime = 0.09;
  static const double life = 0.75;

  static final _flashOuter = Paint()..color = const Color(0xFFFF9A1F);
  static final _flashInner = Paint()..color = const Color(0xFFFFF2B0);
  static final _smoke = Paint();
  static final _rng = math.Random();

  double _age = 0;

  /// Puffs: (ahead, up, start radius, drift) in musket units, a little
  /// random per shot so volleys don't look stamped.
  late final List<(double, double, double, double)> _puffs = [
    for (var i = 0; i < 4; i++)
      (4.0 + i * 6 + _rng.nextDouble() * 3, _rng.nextDouble() * 4 - 2, 4.5 - i * 0.6, 10 + _rng.nextDouble() * 8),
  ];

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final s = power;
    final t = _age / life;
    // Smoke first, so the flash sits on top of it.
    for (final (ahead, up, r0, drift) in _puffs) {
      final r = (r0 + 9 * t) * s;
      final a = (1 - t) * 0.55;
      _smoke.color = Color.fromRGBO(205, 200, 192, a);
      canvas.drawCircle(Offset(dir * ahead * s, (up - drift * t) * s), r, _smoke);
    }
    if (_age < flashTime) {
      final k = 1 - _age / flashTime * 0.4;
      canvas.drawPath(_star(9 * s * k, 4 * s * k), _flashOuter);
      canvas.drawPath(_star(5 * s * k, 2.2 * s * k), _flashInner);
    }
  }

  /// A five-point burst pointing ahead of the barrel.
  Path _star(double long, double short) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = (i / 10) * 2 * math.pi;
      final r = i.isEven ? long : short;
      // Stretched ahead: the flash leaves the barrel, not sideways.
      final x = math.cos(a) * r * (math.cos(a) > 0 ? 1.6 : 0.7) * dir + dir * long * 0.5;
      final y = math.sin(a) * r * 0.8;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }
}
