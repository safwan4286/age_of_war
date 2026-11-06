import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/battle_result.dart';
import '../models/game_data.dart';

/// Progress and settings in one small Hive box. Plain keys and values,
/// read with type checks so a bad value never crashes the menu.
class SaveService extends GetxService {
  static const boxName = 'epoch_save';
  late Box<dynamic> _box;

  static SaveService get to => Get.find<SaveService>();

  final damageNumbers = true.obs;
  final screenShake = true.obs;
  final haptics = true.obs;
  final sound = true.obs;
  final music = true.obs;

  Future<SaveService> init() async {
    _box = await Hive.openBox<dynamic>(boxName);
    damageNumbers.value = _bool('damageNumbers', true);
    screenShake.value = _bool('screenShake', true);
    haptics.value = _bool('haptics', true);
    sound.value = _bool('sound', true);
    music.value = _bool('music', true);
    return this;
  }

  bool _bool(String k, bool fallback) {
    final v = _box.get(k);
    return v is bool ? v : fallback;
  }

  int _int(String k) {
    final v = _box.get(k);
    return v is int ? v : 0;
  }

  // ------------------------------------------------------------ progress

  int bestStars(Difficulty d) => _int('stars_${d.name}');
  int wins(Difficulty d) => _int('wins_${d.name}');
  int get totalStars =>
      Difficulty.values.fold(0, (sum, d) => sum + bestStars(d));

  /// Normal unlocks after a win on Easy, Hard after a win on Normal.
  bool unlocked(Difficulty d) => switch (d) {
    Difficulty.easy => true,
    Difficulty.normal => wins(Difficulty.easy) > 0,
    Difficulty.hard => wins(Difficulty.normal) > 0,
  };

  /// Stores the result; returns it marked [BattleResult.newBest] when the
  /// stars beat the old record.
  Future<BattleResult> record(BattleResult r) async {
    if (!r.victory) return r;
    final key = r.difficulty.name;
    await _box.put('wins_$key', wins(r.difficulty) + 1);
    final best = bestStars(r.difficulty);
    if (r.stars <= best) return r;
    await _box.put('stars_$key', r.stars);
    return r.copyWith(newBest: true);
  }

  bool get tutorialSeen => _bool('tutorialSeen', false);
  Future<void> markTutorialSeen() => _box.put('tutorialSeen', true);

  // ------------------------------------------------------------ settings

  Future<void> setDamageNumbers(bool v) async {
    damageNumbers.value = v;
    await _box.put('damageNumbers', v);
  }

  Future<void> setScreenShake(bool v) async {
    screenShake.value = v;
    await _box.put('screenShake', v);
  }

  Future<void> setHaptics(bool v) async {
    haptics.value = v;
    await _box.put('haptics', v);
  }

  Future<void> setSound(bool v) async {
    sound.value = v;
    await _box.put('sound', v);
  }

  Future<void> setMusic(bool v) async {
    music.value = v;
    await _box.put('music', v);
  }

  /// Wipes stars, wins and the tutorial flag; keeps settings.
  Future<void> resetProgress() async {
    for (final d in Difficulty.values) {
      await _box.delete('stars_${d.name}');
      await _box.delete('wins_${d.name}');
    }
    await _box.delete('tutorialSeen');
  }
}
