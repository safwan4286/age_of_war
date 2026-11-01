import 'package:get/get.dart';

import 'battle_controller.dart';

class BattleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BattleController>(BattleController.new);
  }
}
