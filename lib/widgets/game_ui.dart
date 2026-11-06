import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../resources/assets.dart';
import '../resources/theme.dart';
import '../services/audio/audio_service.dart';
import '../services/audio/sound_cues.dart';
import '../services/responsiveness/device_manager.dart';

/// Shared game UI: stone panels, chunky cartoon buttons, bars, stars.
///
/// Sizes passed to these widgets are design units; each widget scales them
/// with `.sp`, so callers never do.

/// Button colours: face gradient (top, bottom) and the darker rim it sits on.
enum GameTone {
  gold(Color(0xFFFFD25C), Color(0xFFF0A01E), Color(0xFFA35A0C)),
  stone(Color(0xFF9C8E80), Color(0xFF6F6255), Color(0xFF3F352C)),
  ember(Color(0xFFF77A5A), Color(0xFFD23E25), Color(0xFF7E2312)),
  leaf(Color(0xFF9FE06A), Color(0xFF5BAE2F), Color(0xFF2F6A16));

  const GameTone(this.top, this.bottom, this.rim);

  final Color top;
  final Color bottom;
  final Color rim;
}

/// Stone tablet: dark outline, warm stone gradient, a lighter inner rim and
/// a soft drop shadow. [accent] recolours the outline (e.g. a selected card).
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accent,
    this.radius = 20,
  });

  final Widget child;

  /// Design units; scaled here.
  final EdgeInsets padding;
  final Color? accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = radius.sp;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: accent ?? Pal.ink, width: 3.5.sp),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Pal.stoneTop, Pal.stoneBottom],
        ),
        boxShadow: [BoxShadow(color: Pal.ink.withValues(alpha: 0.55), offset: Offset(0, 6.sp), blurRadius: 6.sp)],
      ),
      child: Container(
        margin: EdgeInsets.all(3.sp),
        padding: EdgeInsets.fromLTRB(
          padding.left.sp,
          padding.top.sp,
          padding.right.sp,
          padding.bottom.sp,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r - 3.sp),
          border: Border.all(color: Pal.stoneRim.withValues(alpha: 0.45), width: 1.5.sp),
        ),
        child: child,
      ),
    );
  }
}

/// Chunky cartoon button: outlined, glossy top, sits on a darker rim and
/// sinks onto it when pressed. Never shorter than 48 dp.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = GameTone.gold,
    this.icon,
    this.width,
    this.height = 56,
    this.fontSize = 24,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final GameTone tone;

  /// What a screen reader says, when the visible label isn't enough.
  final String? semanticsLabel;

  /// Image path shown before the label.
  final String? icon;

  /// Design units; scaled here. Null width = as wide as the parent allows.
  final double? width;
  final double height;
  final double fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tone = enabled ? widget.tone : GameTone.stone;
    final h = math.max(48.0, widget.height.sp);
    final depth = (h * 0.1).clamp(4.0, 8.0);
    final r = h * 0.3;
    final sink = _down ? depth : 0.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: enabled
            ? () {
                _tapSound();
                widget.onTap!();
              }
            : null,
        child: SizedBox(
          width: widget.width?.sp,
          height: h,
          child: Stack(
            children: [
              // Rim the face sits on.
              Positioned.fill(
                top: depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.rim,
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(color: Pal.ink, width: 3.sp),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                left: 0,
                right: 0,
                top: sink,
                bottom: depth - sink,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(color: Pal.ink, width: 3.sp),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [tone.top, tone.bottom],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Gloss on the upper part of the face.
                      Positioned(
                        left: r * 0.4,
                        right: r * 0.4,
                        top: 3.sp,
                        height: (h - depth) * 0.28,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: enabled ? 0.28 : 0.12),
                            borderRadius: BorderRadius.circular(r),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.sp),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  GameImage(widget.icon!, size: widget.fontSize * 1.2),
                                  SizedBox(width: 8.sp),
                                ],
                                Text(
                                  widget.label,
                                  maxLines: 1,
                                  style: AppTheme.display(
                                    widget.fontSize,
                                    color: enabled ? Pal.cream : Pal.muted,
                                  ),
                                ),
                              ],
                            ),
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

/// Small square button for icons/short labels (back, pause, speed).
class GameSquareButton extends StatelessWidget {
  const GameSquareButton({
    super.key,
    required this.label,
    required this.onTap,
    this.semantics,
    this.tone = GameTone.stone,
    this.size = 52,
  });

  final String label;
  final VoidCallback? onTap;
  final String? semantics;
  final GameTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics ?? label,
      child: GameButton(
        label: label,
        onTap: onTap,
        tone: tone,
        width: size,
        height: size,
        fontSize: size * 0.42,
      ),
    );
  }
}

/// Rounded bar with an outlined label inside, so it never relies on colour
/// alone.
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.value,
    required this.color,
    this.label,
    this.width = 180,
    this.height = 22,
    this.reverse = false,
  });

  final double value;
  final Color color;
  final String? label;

  /// Design units; scaled here.
  final double width;
  final double height;

  /// Fill from the right (enemy bar).
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final h = height.sp;
    final light = Color.lerp(color, Colors.white, 0.35)!;
    return Container(
      width: width.sp,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1E140C),
        borderRadius: BorderRadius.circular(h / 2),
        border: Border.all(color: Pal.ink, width: (h * 0.12).clamp(1.5, 3.0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(h / 2),
        child: Stack(
          children: [
            Align(
              alignment: reverse ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 160),
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [light, color],
                    ),
                  ),
                ),
              ),
            ),
            if (label != null)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.sp),
                    child: Text(label!, style: AppTheme.display(height * 0.62).copyWith(height: 1)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 0–3 stars.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 30});

  final int stars;

  /// Design units; scaled here.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of 3 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: (size * 0.08).sp),
              child: GameImage(i < stars ? UiImg.star : UiImg.starEmpty, size: size),
            ),
        ],
      ),
    );
  }
}

/// Image.asset sized in design units, smoothly filtered (HD art).
class GameImage extends StatelessWidget {
  const GameImage(this.path, {super.key, this.size, this.fit = BoxFit.contain, this.opacity = 1});

  final String path;
  final double? size;
  final BoxFit fit;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size?.sp,
      height: size?.sp,
      fit: fit,
      filterQuality: FilterQuality.medium,
      opacity: opacity < 1 ? AlwaysStoppedAnimation(opacity) : null,
    );
  }
}

/// Lays [child] out at [maxWidth] (design units, or the screen width if
/// smaller) and scales it down to fit the height, so a screen never
/// overflows on short phones.
class FitScreen extends StatelessWidget {
  const FitScreen({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(maxWidth.sp, box.maxWidth);
        return SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: w, child: child),
          ),
        );
      },
    );
  }
}

/// Button click, if the audio service is running (it isn't in tests).
void _tapSound() {
  if (Get.isRegistered<AudioService>()) AudioService.to.play(Sfx.tap);
}
