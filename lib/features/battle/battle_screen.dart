import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/theme.dart';
import 'battle_controller.dart';
import 'widgets/battle_overlays.dart';
import 'widgets/hud_actions.dart';
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
                onHorizontalDragUpdate: (d) => c.pan(d.delta.dx),
              ),
            ),
            // HUD lives in the corners, AoW-style, so the plain stays clear.
            const SafeArea(
              child: Stack(
                children: [
                  Align(alignment: Alignment.topCenter, child: HudTop()),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(fit: BoxFit.scaleDown, child: HudUnits()),
                  ),
                  Align(alignment: Alignment.bottomRight, child: HudActions()),
                ],
              ),
            ),
            const Positioned.fill(child: BattleOverlays()),
          ],
        ),
      ),
    );
  }
}
