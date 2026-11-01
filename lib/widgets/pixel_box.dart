import 'package:flutter/material.dart';

import '../resources/theme.dart';

/// Hard-edged panel with a dark outline and a "pixel" drop shadow.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.color = Pal.panel,
    this.padding = const EdgeInsets.all(12),
    this.border = Pal.ink,
  });

  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 3),
        boxShadow: const [BoxShadow(color: Pal.ink, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// Chunky button that sinks 3 px when pressed. Never smaller than 48 dp.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Pal.amber,
    this.textColor = Pal.ink,
    this.icon,
    this.width,
    this.height = 56,
    this.fontSize = 20,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final Widget? icon;
  final double? width;
  final double height;
  final double fontSize;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final face = enabled ? widget.color : Pal.panelHi;
    final shade = Color.lerp(face, Pal.ink, 0.45)!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: widget.height.clamp(48.0, double.infinity),
          child: Stack(
            children: [
              Positioned.fill(
                top: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shade,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Pal.ink, width: 3),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                left: 0,
                right: 0,
                top: _down ? 4 : 0,
                bottom: _down ? 0 : 4,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: face,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Pal.ink, width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: widget.fontSize,
                            color: enabled ? widget.textColor : Pal.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Health / progress bar with a label inside, so it never relies on
/// colour alone.
class PixelBar extends StatelessWidget {
  const PixelBar({
    super.key,
    required this.value,
    required this.color,
    this.label,
    this.width = 180,
    this.height = 18,
    this.reverse = false,
  });

  final double value;
  final Color color;
  final String? label;
  final double width;
  final double height;

  /// Fill from the right (enemy bar).
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Pal.ink,
        border: Border.all(color: Pal.ink, width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Align(
            alignment: reverse ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 160),
              widthFactor: v,
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
          if (label != null)
            Center(
              child: Text(
                label!,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: height * 0.62,
                  color: Pal.cream,
                  height: 1,
                  shadows: const [Shadow(color: Pal.ink, offset: Offset(1, 1))],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 0–3 stars.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 28});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.06),
              child: Image.asset(
                i < stars ? 'assets/images/ui/star.png' : 'assets/images/ui/star_empty.png',
                width: size,
                height: size,
                filterQuality: FilterQuality.none,
              ),
            ),
        ],
      ),
    );
  }
}

/// Image.asset for pixel art: nearest-neighbour, never blurred.
class PixelImage extends StatelessWidget {
  const PixelImage(this.path, {super.key, this.size, this.fit = BoxFit.contain, this.opacity = 1});

  final String path;
  final double? size;
  final BoxFit fit;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.none,
      opacity: opacity < 1 ? AlwaysStoppedAnimation(opacity) : null,
    );
  }
}
