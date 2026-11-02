import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/theme.dart';
import '../../services/responsiveness/device_manager.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/scenic_backdrop.dart';
import 'settings_controller.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.save;
    return Scaffold(
      body: ScenicBackdrop(
        scrim: 0.55,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(14.sp),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 560.sp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GameSquareButton(label: '<', semantics: 'Back', onTap: Get.back),
                        SizedBox(width: 14.sp),
                        Text('SETTINGS', style: AppTheme.display(34)),
                      ],
                    ),
                    SizedBox(height: 14.sp),
                    GamePanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          Obx(() => _Toggle('Damage numbers', s.damageNumbers.value, c.setDamageNumbers)),
                          const _Divider(),
                          Obx(() => _Toggle('Screen shake', s.screenShake.value, c.setScreenShake)),
                          const _Divider(),
                          Obx(() => _Toggle('Vibration', s.haptics.value, c.setHaptics)),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.sp),
                    Obx(
                      () => GameButton(
                        label: c.confirmingReset.value ? 'TAP AGAIN TO RESET' : 'RESET PROGRESS',
                        onTap: c.tapReset,
                        tone: c.confirmingReset.value ? GameTone.ember : GameTone.stone,
                        fontSize: 22,
                      ),
                    ),
                    SizedBox(height: 12.sp),
                    GameButton(
                      label: 'CREDITS & LICENCES',
                      onTap: () => c.showLicences(context),
                      tone: GameTone.stone,
                      fontSize: 22,
                    ),
                    SizedBox(height: 12.sp),
                    Text(
                      'Stone Age slice · v0.1.0\nNo ads in this build.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(14, color: Pal.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 2.sp, color: Pal.ink.withValues(alpha: 0.35));
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 58.sp),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTheme.body(20))),
            Text(value ? 'ON' : 'OFF', style: AppTheme.display(16, color: value ? Pal.amber : Pal.muted)),
            SizedBox(width: 8.sp),
            Transform.scale(scale: DeviceManager.instance.scaleFactor, child: Switch(value: value, onChanged: onChanged)),
          ],
        ),
      ),
    );
  }
}
