import 'package:get/get.dart';

import '../../models/game_data.dart';
import '../../resources/routes.dart';
import '../../services/save_service.dart';

class DifficultyController extends GetxController {
  final SaveService save = SaveService.to;

  static const blurbs = {
    Difficulty.easy: 'A sleepy tribe. Learn the ropes.',
    Difficulty.normal: 'Reads your army and counters it.',
    Difficulty.hard: 'Richer, faster, saves for Dino Riders.',
  };

  int stars(Difficulty d) => save.bestStars(d);
  bool unlocked(Difficulty d) => save.unlocked(d);

  String lockHint(Difficulty d) => switch (d) {
    Difficulty.easy => '',
    Difficulty.normal => 'Win on Easy to unlock',
    Difficulty.hard => 'Win on Normal to unlock',
  };

  void start(Difficulty d) {
    if (!unlocked(d)) return;
    Get.toNamed(Routes.battle, arguments: d);
  }
}
