import 'package:flame/components.dart';

import '../world_layout.dart';

/// One background layer. [factor] is how much of the camera's movement
/// the layer follows on screen: 1 = moves with the ground, 0.2 = far sky.
/// Manual parallax keeps it in world space with everything else.
class BgLayer extends SpriteComponent {
  BgLayer({required Sprite sprite, required this.factor, required int priority})
    : super(
        sprite: sprite,
        size: Vector2(Layout.bgW, Layout.worldH),
        position: Vector2(Layout.bgLeft, 0),
        priority: priority,
      );

  final double factor;

  /// Called by the game each frame with the camera's left edge.
  void follow(double camLeft) {
    x = Layout.bgLeft + camLeft * (1 - factor);
  }
}
