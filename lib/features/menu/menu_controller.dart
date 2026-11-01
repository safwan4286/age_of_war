import 'package:get/get.dart';

import '../../resources/routes.dart';
import '../../services/save_service.dart';

class MenuController extends GetxController {
  final SaveService save = SaveService.to;

  final totalStars = 0.obs;

  @override
  void onReady() {
    super.onReady();
    refreshStars();
  }

  void refreshStars() => totalStars.value = save.totalStars;

  Future<void> play() async {
    await Get.toNamed(Routes.difficulty);
    refreshStars();
  }

  Future<void> openSettings() async {
    await Get.toNamed(Routes.settings);
    refreshStars();
  }
}
