import 'dart:math';

import 'package:flutter/widgets.dart';

/// UI sizes in design units: `16.sp` is 16 on the reference phone and
/// scales with the screen (same approach as Kindose, landscape reference).
///
/// Rule in this project: the shared widgets in `widgets/game_ui.dart`
/// take design units and scale them themselves; screens use `.sp` only for
/// raw Flutter sizes (SizedBox, EdgeInsets, Container).
extension ScreenSize on num {
  double get sp => DeviceManager.instance.setSp(toDouble());
}

class DeviceManager {
  DeviceManager._internal();

  static final DeviceManager instance = DeviceManager._internal();

  /// Reference screen: a mid-size phone held sideways (logical pixels).
  final double width = 800.0;
  final double height = 380.0;

  /// Small phones scale down a little; tablets scale up a little but keep
  /// the phone layout (the HUD stays in the corners).
  static const double minScale = 0.82;
  static const double maxScale = 1.25;

  double? _screenWidth;
  double? _screenHeight;
  double? _textScale;

  void init(BuildContext context) => initWith(MediaQuery.of(context));

  /// Called from the app builder with the (text-scale-capped) MediaQuery.
  void initWith(MediaQueryData mq) {
    _screenWidth = mq.size.width;
    _screenHeight = mq.size.height;
    _textScale = mq.textScaler.scale(1);
  }

  double get scaleFactor {
    final w = _screenWidth, h = _screenHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return 1.0;
    // Landscape game: height is the tight side, so it weighs in as well as
    // the diagonal (a very wide, short phone must not scale up).
    final diag = sqrt(w * w + h * h) / sqrt(width * width + height * height);
    final byHeight = h / height;
    return min(diag, byHeight).clamp(minScale, maxScale);
  }

  double setSp(double size) => size * scaleFactor;

  double get screenWidth => _screenWidth ?? width;
  double get screenHeight => _screenHeight ?? height;
  double get textScale => _textScale ?? 1.0;
}
