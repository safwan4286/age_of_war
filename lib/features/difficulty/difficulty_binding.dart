import 'package:get/get.dart';

import 'difficulty_controller.dart';

class DifficultyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DifficultyController>(DifficultyController.new);
  }
}
