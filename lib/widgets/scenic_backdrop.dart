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

  Widget _layer(String path, double travel) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(-_drift.value * travel, 0),
        child: child,
      ),
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: Image.asset(
          'assets/images/$path',
          fit: BoxFit.fitHeight,
          height: double.infinity,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Pal.night,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _layer(Img.bgSky, 0.03),
          _layer(Img.bgHills, 0.08),
          _layer(Img.bgNear, 0.16),
          ColoredBox(color: Pal.ink.withValues(alpha: widget.scrim)),
          widget.child,
        ],
      ),
    );
  }
}
