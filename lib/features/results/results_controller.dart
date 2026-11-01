import 'package:get/get.dart';

import '../../models/battle_result.dart';
import '../../models/game_data.dart';
import '../../resources/routes.dart';
import '../../services/save_service.dart';

class ResultsController extends GetxController {
  late final BattleResult result;

  /// Stars appear one by one.
  final shownStars = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    result = arg is BattleResult
        ? arg
        : const BattleResult(
            difficulty: Difficulty.easy,
            victory: false,
            stars: 0,
            seconds: 0,
            kills: 0,
            goldEarned: 0,
            xp: 0,
            baseHpLeft: 0,
          );
  }

  @override
  void onReady() {
    super.onReady();
    _revealStars();
  }

  Future<void> _revealStars() async {
    for (var i = 1; i <= result.stars; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (isClosed) return;
      shownStars.value = i;
    }
  }

  /// The next difficulty, when this win just opened or already opened it.
  Difficulty? get next {
    if (!result.victory) return null;
    final i = result.difficulty.index + 1;
    if (i >= Difficulty.values.length) return null;
    final d = Difficulty.values[i];
    return SaveService.to.unlocked(d) ? d : null;
  }

  void retry() => Get.offNamed(Routes.battle, arguments: result.difficulty);

  void playNext() {
    final d = next;
    if (d != null) Get.offNamed(Routes.battle, arguments: d);
  }

  void menu() => Get.offAllNamed(Routes.menu);
}
