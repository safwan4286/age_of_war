import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../resources/assets.dart';
import '../battle_controller.dart';
import 'hud_top.dart';

/// Bottom-right corner: build / sell turrets on the base's ledges.
class HudActions extends GetView<BattleController> {
  const HudActions({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
      child: Obx(() {
        final built = c.turrets.where((t) => t).length;
        final slots = c.turrets.length;
        return HudIconButton(
          icon: UiImg.turret,
          label: 'TURRET $built/$slots',
          semantics: 'Turrets: $built of $slots ledges built. Open the build menu',
          enabled: c.canBuildTurret || built > 0,
          onTap: c.openTurrets,
          size: 64,
        );
      }),
    );
  }
}
