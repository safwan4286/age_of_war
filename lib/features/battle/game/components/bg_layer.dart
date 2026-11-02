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
class BgLayer extends PositionComponent {
  BgLayer({
    required this.sprite,
    required this.factor,
    required int priority,
    this.layerTop = 0,
    this.layerH = Layout.worldH,
  }) : super(priority: priority);

  final Sprite sprite;
  final double factor;

  /// Vertical placement in world units; the width follows the picture.
  final double layerTop;
  final double layerH;
  double _camLeft = 0;
  double _viewW = 0;

  double get tileW => layerH * sprite.srcSize.x / sprite.srcSize.y;

  /// Called by the game whenever the camera moves.
  void follow(double camLeft, double viewW) {
    _camLeft = camLeft;
    _viewW = viewW;
  }

  @override
  void render(Canvas canvas) {
    final tw = tileW;
    if (tw <= 0 || _viewW <= 0) return;
    final size = Vector2(tw, layerH);
    final origin = Layout.bgLeft + _camLeft * (1 - factor);
    final first = ((_camLeft - origin) / tw).floor();
    for (var k = first; origin + k * tw < _camLeft + _viewW; k++) {
      final x = origin + k * tw;
      if (k.isEven) {
        sprite.render(canvas, position: Vector2(x, layerTop), size: size);
      } else {
        canvas
          ..save()
          ..translate(x + tw, layerTop)
          ..scale(-1, 1);
        sprite.render(canvas, size: size);
        canvas.restore();
      }
    }
  }
}
