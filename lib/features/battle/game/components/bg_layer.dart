import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../world_layout.dart';

/// One background layer. [factor] is how much of the camera's movement
/// the layer follows on screen: 1 = moves with the ground, 0.2 = far sky.
/// Manual parallax keeps it in world space with everything else.
///
/// The picture is drawn [layerH] tall at its own aspect and repeated to cover
/// whatever the camera sees, every other copy mirrored so the joins are
/// seamless. Wide phones and overscroll never show an edge.
///
/// [swap] cross-fades to another era's picture.
class BgLayer extends PositionComponent {
  BgLayer({
    required Sprite sprite,
    required this.factor,
    required int priority,
    double layerTop = 0,
    double layerH = Layout.worldH,
  }) : _now = _Pic(sprite, layerTop, layerH),
       super(priority: priority);

  final double factor;
  _Pic _now;
  _Pic? _old;
  double _fade = 1;
  double _camLeft = 0;
  double _viewW = 0;

  static const double fadeTime = 0.9;

  /// Vertical placement in world units; the width follows the picture.
  double get layerTop => _now.top;
  double get layerH => _now.h;

  /// Called by the game whenever the camera moves.
  void follow(double camLeft, double viewW) {
    _camLeft = camLeft;
    _viewW = viewW;
  }

  void swap(Sprite sprite, {required double layerTop, required double layerH}) {
    _old = _now;
    _now = _Pic(sprite, layerTop, layerH);
    _fade = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_old == null) return;
    _fade = math.min(1, _fade + dt / fadeTime);
    if (_fade >= 1) _old = null;
  }

  @override
  void render(Canvas canvas) {
    if (_viewW <= 0) return;
    final old = _old;
    if (old != null) _draw(canvas, old, Paint()..color = Color.fromRGBO(255, 255, 255, 1 - _fade));
    _draw(canvas, _now, old == null ? null : (Paint()..color = Color.fromRGBO(255, 255, 255, _fade)));
  }

  void _draw(Canvas canvas, _Pic p, Paint? paint) {
    final tw = p.h * p.sprite.srcSize.x / p.sprite.srcSize.y;
    if (tw <= 0) return;
    final size = Vector2(tw, p.h);
    final origin = Layout.bgLeft + _camLeft * (1 - factor);
    final first = ((_camLeft - origin) / tw).floor();
    for (var k = first; origin + k * tw < _camLeft + _viewW; k++) {
      final x = origin + k * tw;
      if (k.isEven) {
        p.sprite.render(canvas, position: Vector2(x, p.top), size: size, overridePaint: paint);
      } else {
        canvas
          ..save()
          ..translate(x + tw, p.top)
          ..scale(-1, 1);
        p.sprite.render(canvas, size: size, overridePaint: paint);
        canvas.restore();
      }
    }
  }
}

class _Pic {
  const _Pic(this.sprite, this.top, this.h);

  final Sprite sprite;
  final double top;
  final double h;
}
