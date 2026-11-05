import 'package:flutter/material.dart';

import '../resources/assets.dart';
import '../resources/theme.dart';

/// The battle's background layers behind menus, slowly drifting, with a
/// dark scrim so text stays readable.
class ScenicBackdrop extends StatefulWidget {
  const ScenicBackdrop({super.key, required this.child, this.scrim = 0.45});

  final Widget child;
  final double scrim;

  @override
  State<ScenicBackdrop> createState() => _ScenicBackdropState();
}

class _ScenicBackdropState extends State<ScenicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  /// One layer drawn at a fraction of the screen height ([top] and
  /// [height] as fractions), drifting sideways by [travel] of its width.
  Widget _layer(String path, double travel, {double top = 0, double height = 1}) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight * height;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: box.maxHeight * top,
              height: h,
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(-_drift.value * travel, 0),
                  child: child,
                ),
                // Repeated with every other copy mirrored, like the
                // battlefield, so any screen width is covered seamlessly.
                child: OverflowBox(
                  maxWidth: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var k = 0; k < 4; k++)
                        Transform.flip(
                          flipX: k.isOdd,
                          child: Image.asset(
                            'assets/images/$path',
                            height: h,
                            fit: BoxFit.fitHeight,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Pal.night,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Same proportions as the battlefield's layers (units.json world).
          _layer(Img.bg('stone', 'sky'), 0.03, top: -0.05, height: 1.1),
          _layer(Img.bg('stone', 'hills'), 0.08, height: 1.0),
          _layer(Img.bg('stone', 'near'), 0.16, top: 0.3, height: 0.74),
          ColoredBox(color: Pal.ink.withValues(alpha: widget.scrim)),
          widget.child,
        ],
      ),
    );
  }
}
