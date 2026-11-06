import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/save_service.dart';

class SettingsController extends GetxController {
  final SaveService save = SaveService.to;

  final confirmingReset = false.obs;

  void setDamageNumbers(bool v) => save.setDamageNumbers(v);
  void setScreenShake(bool v) => save.setScreenShake(v);
  void setHaptics(bool v) => save.setHaptics(v);
  void setSound(bool v) => save.setSound(v);
  void setMusic(bool v) => save.setMusic(v);

  /// First tap arms the button, second tap wipes.
  Future<void> tapReset() async {
    if (!confirmingReset.value) {
      confirmingReset.value = true;
      return;
    }
    await save.resetProgress();
    confirmingReset.value = false;
    Get.snackbar(
      'Progress reset',
      'Stars, wins and the tutorial are back to the start.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  void showLicences(BuildContext context) => showLicensePage(
    context: context,
    applicationName: 'Epoch Clash',
    applicationVersion: '0.2.0 · Stone and Medieval ages',
  );
}
