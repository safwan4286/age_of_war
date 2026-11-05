import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/theme.dart';
import '../../services/responsiveness/device_manager.dart';
import 'battle_controller.dart';
import 'widgets/battle_overlays.dart';
import 'widgets/hud_actions.dart';
import 'widgets/hud_insets.dart';
import 'widgets/hud_top.dart';
import 'widgets/hud_units.dart';

class BattleScreen extends GetView<BattleController> {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.pause();
      },
      child: Scaffold(
        backgroundColor: Pal.night,
        body: Stack(
          children: [
            Positioned.fill(
              child: Obx(
                () => GameWidget(
                  key: ValueKey(c.round.value),
                  game: c.game,
                  loadingBuilder: (_) => const ColoredBox(color: Pal.night),
                ),
              ),
            ),
            // Drag anywhere on the battlefield to look along the lane.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => c.panStart(),
                onHorizontalDragUpdate: (d) => c.pan(d.delta.dx),
                onHorizontalDragEnd: (_) => c.panEnd(),
                onHorizontalDragCancel: c.panEnd,
              ),
            ),
            // HUD lives in the corners, AoW-style, so the plain stays clear.
            // It hugs the edges and only steps around the camera cutout
            // where the cutout really is (see HudInsets).
            Positioned.fill(
              child: Builder(
                builder: (context) {
                  final mq = MediaQuery.of(context);
                  final (cutouts, known) = HudInsets.cutoutsOf(mq);
                  final size = mq.size;
                  ({double left, double right}) strip(double top, double bottom) => HudInsets.forStrip(
                    screen: size,
                    cutouts: cutouts,
                    safe: mq.viewPadding,
                    top: top,
                    bottom: bottom,
                    cutoutsKnown: known,
                  );
                  final top = strip(0, 120.sp);
                  final low = strip(size.height - 100.sp, size.height);
                  // Without cutout info (iOS) keep clear of the home bar.
                  final bottom = known ? 0.0 : mq.viewPadding.bottom;
                  return Stack(
                    children: [
                      Positioned(
                        top: math.max(mq.viewPadding.top, 0),
                        left: top.left,
                        right: top.right,
                        child: const HudTop(),
                      ),
                      Positioned(
                        left: low.left,
                        bottom: bottom,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: size.width * 0.6),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: HudUnits()),
                        ),
                      ),
                      Positioned(right: low.right, bottom: bottom, child: const HudActions()),
                    ],
                  );
                },
              ),
            ),
            const Positioned.fill(child: BattleOverlays()),
          ],
        ),
      ),
    );
  }
}
