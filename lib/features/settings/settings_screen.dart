import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/theme.dart';
import '../../widgets/pixel_box.dart';
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
        scrim: 0.7,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PixelButton(
                          label: '<',
                          onTap: Get.back,
                          width: 56,
                          color: Pal.panelHi,
                          textColor: Pal.cream,
                        ),
                        const SizedBox(width: 16),
                        Text('SETTINGS', style: AppTheme.display(28)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PixelPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          Obx(() => _Toggle('Damage numbers', s.damageNumbers.value, c.setDamageNumbers)),
                          Obx(() => _Toggle('Screen shake', s.screenShake.value, c.setScreenShake)),
                          Obx(() => _Toggle('Vibration', s.haptics.value, c.setHaptics)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => PixelButton(
                        label: c.confirmingReset.value ? 'TAP AGAIN TO RESET' : 'RESET PROGRESS',
                        onTap: c.tapReset,
                        color: c.confirmingReset.value ? Pal.ember : Pal.panelHi,
                        textColor: Pal.cream,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PixelButton(
                      label: 'CREDITS & LICENCES',
                      onTap: () => c.showLicences(context),
                      color: Pal.panelHi,
                      textColor: Pal.cream,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 12),
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

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTheme.body(20))),
            Text(value ? 'ON' : 'OFF', style: AppTheme.display(14, color: value ? Pal.amber : Pal.muted)),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
