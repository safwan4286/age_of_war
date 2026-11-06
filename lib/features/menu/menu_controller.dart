import 'package:get/get.dart';

import '../../resources/routes.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/sound_cues.dart';
import '../../services/save_service.dart';

class MenuController extends GetxController {
  final SaveService save = SaveService.to;

  final totalStars = 0.obs;

  @override
  void onReady() {
    super.onReady();
    refreshStars();
    _menuMusic();
  }

  void _menuMusic() {
    if (Get.isRegistered<AudioService>()) AudioService.to.music(Music.menu);
  }

  void refreshStars() => totalStars.value = save.totalStars;

  Future<void> play() async {
    await Get.toNamed(Routes.difficulty);
    refreshStars();
    _menuMusic();
  }

  Future<void> openSettings() async {
    await Get.toNamed(Routes.settings);
    refreshStars();
  }
}
