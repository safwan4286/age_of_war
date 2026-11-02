import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../services/responsiveness/device_manager.dart';
import '../../../widgets/game_ui.dart';
import '../battle_controller.dart';

/// Bottom-right corner: upgrades and turrets, Age of War style.
class HudActions extends GetView<BattleController> {
  const HudActions({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 10.sp, 6.sp),
      child: Obx(() {
        // Rebuild when gold or levels change.
        c.gold.value;
        c.upgrades.length;
        final built = c.turrets.where((t) => t).length;
        final slots = c.turrets.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.fitness_center_rounded,
              semantics: c.canUpgrade ? 'Upgrades, one is affordable' : 'Upgrades',
              glow: c.canUpgrade,
              onTap: c.openUpgrades,
            ),
            SizedBox(width: 8.sp),
            _ActionButton(
              image: UiImg.turret,
              semantics: 'Turrets: $built of $slots ledges built. Open the build menu',
              glow: c.canBuildTurret,
              badge: '$built/$slots',
              onTap: c.openTurrets,
            ),
          ],
        );
      }),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.semantics,
    required this.onTap,
    this.icon,
    this.image,
    this.glow = false,
    this.badge,
  });

  final IconData? icon;
  final String? image;
  final String semantics;
  final VoidCallback onTap;
  final bool glow;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final s = 48.sp;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: s,
                height: s,
                padding: EdgeInsets.all(6.sp),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13.sp),
                  border: Border.all(color: Pal.ink, width: 2.5.sp),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [GameTone.gold.top, GameTone.gold.bottom],
                  ),
                  boxShadow: [
                    BoxShadow(color: GameTone.gold.rim, offset: Offset(0, 3.sp)),
                    if (glow) BoxShadow(color: Pal.amber.withValues(alpha: 0.7), blurRadius: 12.sp),
                  ],
                ),
                child: image != null
                    ? GameImage(image!)
                    : Icon(icon, size: s * 0.62, color: Pal.cream, shadows: AppTheme.outline(s * 0.4)),
              ),
              if (badge != null)
                Positioned(
                  right: -4.sp,
                  bottom: -6.sp,
                  child: Text(badge!, style: AppTheme.display(12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
