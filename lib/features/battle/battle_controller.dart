import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/battle_result.dart';
import '../../models/game_data.dart';
import '../../resources/routes.dart';
import '../../services/game_data_service.dart';
import '../../services/save_service.dart';
import '../../services/sim/battle_sim.dart';
import '../../services/sim/enemy_ai.dart';
import 'game/battle_game.dart';

enum BattleOverlay { none, tutorial, paused, evolveTeaser, turrets }

/// Owns one battle: the sim, the enemy AI and the Flame view. The HUD
/// reads the Rx values below, refreshed about 10 times a second.
class BattleController extends GetxController {
  final GameData data = GameDataService.to.data;
  final SaveService save = SaveService.to;

  late final Difficulty difficulty;
  late BattleSim sim;
  late EnemyAi ai;
  late BattleGame game;

  /// Bumped on restart; the screen keys its GameWidget on it.
  final round = 0.obs;

  static const hudEvery = 0.1;
  double _hudClock = 0;
  bool _finished = false;
  int _lastBaseBuzz = 0;

  // HUD state.
  final gold = 0.obs;
  final xp = 0.obs;
  final playerHp = 1.0.obs;
  final enemyHp = 1.0.obs;
  final queue = <String>[].obs;
  final trainFraction = 0.0.obs;
  final meteorFraction = 0.0.obs;
  /// One entry per turret ledge: built or empty.
  final turrets = <bool>[].obs;
  final population = 0.obs;
  final seconds = 0.obs;
  final speed = 1.obs;
  final overlay = BattleOverlay.none.obs;
  final tutorialStep = 0.obs;

  static const tutorialSteps = 3;

  UnitDef get chief => data.unit('chief');
  int get evolveXp => data.evolveXp;
  bool get canEvolve => xp.value >= data.evolveXp;
  bool get meteorReady => meteorFraction.value >= 1;
  int get popCap => data.popCap;
  bool get popFull => population.value >= data.popCap;
  bool get canBuildTurret =>
      turrets.contains(false) && gold.value >= data.turret.cost;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    difficulty = arg is Difficulty ? arg : Difficulty.easy;
    _start();
    if (!save.tutorialSeen) _open(BattleOverlay.tutorial);
  }

  void _start() {
    _finished = false;
    _hudClock = 0;
    sim = BattleSim(
      data,
      difficulty: difficulty,
      seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
    );
    ai = EnemyAi(sim);
    game = BattleGame(
      sim: sim,
      ai: ai,
      onTick: _onTick,
      onEvents: _onEvents,
      damageNumbers: save.damageNumbers.value,
      screenShake: save.screenShake.value,
    );
    game.speed = speed.value.toDouble();
    _refresh();
  }

  // ------------------------------------------------------------- frame

  void _onTick(double dt) {
    _hudClock += dt;
    if (_hudClock < hudEvery) return;
    _hudClock = 0;
    _refresh();
  }

  void _refresh() {
    final me = sim[Side.player];
    gold.value = me.gold.floor();
    xp.value = me.xp;
    playerHp.value = me.baseHp / data.baseHp;
    enemyHp.value = sim[Side.enemy].baseHp / data.baseHp;
    final ids = me.queue.map((u) => u.id).toList();
    if (!_sameList(ids, queue)) queue.assignAll(ids);
    trainFraction.value = me.queue.isEmpty
        ? 0
        : 1 - (me.trainLeft / me.queue.first.trainTime).clamp(0.0, 1.0);
    meteorFraction.value = sim.meteorFraction(Side.player);
    if (!_sameBools(me.turrets, turrets)) turrets.assignAll(me.turrets);
    population.value = sim.population(Side.player);
    seconds.value = sim.time.floor();
  }

  static bool _sameBools(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onEvents(List<SimEvent> events) {
    for (final e in events) {
      switch (e.type) {
        case SimEventType.meteorImpact:
          _buzz(HapticFeedback.lightImpact);
        case SimEventType.baseHit when e.side == Side.player:
          final now = sim.time.floor();
          if (now != _lastBaseBuzz) {
            _lastBaseBuzz = now;
            _buzz(HapticFeedback.selectionClick);
          }
        case SimEventType.gameOver:
          _finish();
        default:
          break;
      }
    }
  }

  void _buzz(Future<void> Function() f) {
    if (save.haptics.value) f();
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _refresh();
    _buzz(HapticFeedback.heavyImpact);
    final me = sim[Side.player];
    var result = BattleResult(
      difficulty: difficulty,
      victory: sim.outcome == BattleOutcome.victory,
      stars: sim.stars,
      seconds: sim.time,
      kills: me.kills,
      goldEarned: me.goldEarned,
      xp: me.xp,
      baseHpLeft: me.baseHp / data.baseHp,
    );
    final played = round.value;
    result = await save.record(result);
    // Let the last blow land on screen before leaving.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (isClosed || played != round.value) return;
    game.frozen = true;
    Get.offNamed(Routes.results, arguments: result);
  }

  // ---------------------------------------------------------- commands

  /// Returns false when the unit can't be queued (feedback is the
  /// card's own shake).
  bool train(String id) {
    final ok = sim.queueUnit(Side.player, id);
    _buzz(ok ? HapticFeedback.selectionClick : HapticFeedback.vibrate);
    _refresh();
    return ok;
  }

  bool canAfford(UnitDef u) => gold.value >= u.cost;
  bool get queueFull => queue.length >= data.queueMax;

  /// Opens the ledge picker (the battle waits meanwhile).
  void openTurrets() => _open(BattleOverlay.turrets);

  void buildTurret(int slot) {
    final ok = sim.buyTurret(Side.player, slot);
    _buzz(ok ? HapticFeedback.mediumImpact : HapticFeedback.vibrate);
    _refresh();
  }

  void sellTurret(int slot) {
    if (sim.sellTurret(Side.player, slot)) {
      _buzz(HapticFeedback.selectionClick);
    }
    _refresh();
  }

  void castMeteor() {
    if (sim.castMeteor(Side.player)) {
      _buzz(HapticFeedback.mediumImpact);
    } else {
      _buzz(HapticFeedback.vibrate);
    }
    _refresh();
  }

  void tapEvolve() {
    if (canEvolve) {
      _open(BattleOverlay.evolveTeaser);
    } else {
      _buzz(HapticFeedback.vibrate);
    }
  }

  void toggleSpeed() {
    speed.value = speed.value == 1 ? 2 : 1;
    game.speed = speed.value.toDouble();
  }

  void pan(double dx) => game.panBy(dx);

  // ---------------------------------------------------------- overlays

  void pause() {
    if (_finished || overlay.value != BattleOverlay.none) return;
    _open(BattleOverlay.paused);
  }

  void _open(BattleOverlay o) {
    overlay.value = o;
    game.frozen = true;
  }

  void _close() {
    overlay.value = BattleOverlay.none;
    if (!_finished) game.frozen = false;
  }

  void resume() => _close();

  void nextTutorialStep() {
    if (tutorialStep.value < tutorialSteps - 1) {
      tutorialStep.value++;
      return;
    }
    save.markTutorialSeen();
    _close();
  }

  void closeOverlay() => _close();

  /// Same difficulty, fresh battle, same screen.
  void restart() {
    game.frozen = true;
    _start();
    overlay.value = BattleOverlay.none;
    round.value++;
  }

  void quit() {
    game.frozen = true;
    Get.offAllNamed(Routes.menu);
  }
}
