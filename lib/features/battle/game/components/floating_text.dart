import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../../../resources/theme.dart';

/// "+65" over a kill, or a damage number. Rises, then removes itself.
class FloatingText extends TextComponent {
  FloatingText(String text, Vector2 at, {Color color = Pal.amber, double size = 18})
    : super(
        text: text,
        position: at,
        anchor: Anchor.bottomCenter,
        priority: 40,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: size,
            color: color,
            shadows: AppTheme.outline(size),
          ),
        ),
      );

  static const double life = 0.9;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    y -= dt * 46;
    if (_age >= life) removeFromParent();
  }
}
