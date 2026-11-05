import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How far the HUD keeps from the left and right screen edges.
///
/// SafeArea pads both sides by the camera cutout's width for the whole
/// screen height, which pushed the HUD far into the battlefield. The
/// cutout only occupies part of one edge, so when the platform reports it
/// (Android), a HUD strip only avoids it if the cutout actually reaches
/// that strip. Without cutout info (iOS) it falls back to the safe insets.
class HudInsets {
  HudInsets._();

  /// Smallest gap to the edge, for rounded screen corners.
  static const double margin = 12;

  /// Left/right insets for a horizontal strip of the screen from [top] to
  /// [bottom] (logical pixels).
  static ({double left, double right}) forStrip({
    required Size screen,
    required List<Rect> cutouts,
    required EdgeInsets safe,
    required double top,
    required double bottom,
    bool cutoutsKnown = true,
  }) {
    if (!cutoutsKnown) {
      return (left: math.max(margin, safe.left), right: math.max(margin, safe.right));
    }
    var left = margin, right = margin;
    for (final c in cutouts) {
      if (c.bottom <= top || c.top >= bottom) continue; // not in this strip
      if (c.center.dx < screen.width / 2) {
        left = math.max(left, c.right + margin / 2);
      } else {
        right = math.max(right, screen.width - c.left + margin / 2);
      }
    }
    return (left: left, right: right);
  }

  /// The reported camera cutouts, and whether the platform reports them.
  static (List<Rect>, bool) cutoutsOf(MediaQueryData mq) {
    final rects = [
      for (final f in mq.displayFeatures)
        if (f.type == DisplayFeatureType.cutout) f.bounds,
    ];
    // Android phones put the camera in the middle of a side in landscape,
    // well clear of the top and bottom HUD strips, so there the side
    // insets can be ignored even if the cutout isn't reported. Elsewhere
    // (iPhone notch, rounded corners) a side inset means "keep it".
    final known = rects.isNotEmpty ||
        defaultTargetPlatform == TargetPlatform.android ||
        (mq.viewPadding.left == 0 && mq.viewPadding.right == 0);
    return (rects, known);
  }
}
