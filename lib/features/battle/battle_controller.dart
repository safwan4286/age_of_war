import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/battle_result.dart';
import '../../models/game_data.dart';
import '../../resources/routes.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/sound_cues.dart';
import '../../services/game_data_service.dart';
import '../../services/save_service.dart';
import '../../services/sim/battle_sim.dart';
import '../../services/sim/enemy_ai.dart';
import 'game/battle_game.dart';

enum BattleOverlay { none, tutorial, paused, evolveTeaser, turrets, upgrades }

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

  /// Upgrade id -> level bought this battle.
  final upgrades = <String, int>{}.obs;
  final population = 0.obs;

  /// Index into data.eras for each side (the HUD swaps shop and icons).
  final era = 0.obs;
  final enemyEra = 0.obs;
  final seconds = 0.obs;
  final speed = 1.obs;
  final overlay = BattleOverlay.none.obs;
  final tutorialStep = 0.obs;

  static const tutorialSteps = 3;

  /// The player's current age: its units, turret and special.
  EraDef get playerEra => data.era(era.value);
  List<UnitDef> get shopUnits => playerEra.units;
  bool get lastEra => era.value >= data.eras.length - 1;

  /// XP needed for the next age; 0 in the last one.
  int get evolveXp => lastEra ? 0 : playerEra.evolveXp;
  bool get canEvolve => !lastEra && xp.value >= evolveXp;

  /// XP bar fill toward the next age (full in the last one).
  double get evolveFraction => evolveXp == 0 ? 1 : (xp.value / evolveXp).clamp(0.0, 1.0);
  bool get meteorReady => meteorFraction.value >= 1;
  int get popCap => data.popCap;
  bool get popFull => population.value >= data.popCap;
  bool get canBuildTurret =>
      turrets.contains(false) && gold.value >= playerEra.turret.cost;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    difficulty = arg is Difficulty ? arg : Difficulty.easy;
    _start();
    if (!save.tutorialSeen) _open(BattleOverlay.tutorial);
  }

  @override
  void onClose() {
    // Battle art is big (two ages of unit strips); menus don't need it.
    game.images.clearCache();
    super.onClose();
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
    _battleMusic();
  }

  // ------------------------------------------------------------- sound

  AudioService? get _audio => Get.isRegistered<AudioService>() ? AudioService.to : null;

  void _sfx(Sfx s) => _audio?.play(s);

  /// Each age has its own battle track.
  void _battleMusic() => _audio?.music(Music.battle(playerEra.id));

  void _denied() {
    _buzz(HapticFeedback.vibrate);
    _sfx(Sfx.denied);
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
    era.value = me.era;
    enemyEra.value = sim[Side.enemy].era;
    playerHp.value = me.baseHp / sim.maxHp(Side.player);
    enemyHp.value = sim[Side.enemy].baseHp / sim.maxHp(Side.enemy);
    final ids = me.queue.map((u) => u.id).toList();
    if (!_sameList(ids, queue)) queue.assignAll(ids);
    trainFraction.value = me.queue.isEmpty
        ? 0
        : 1 - (me.trainLeft / me.queue.first.trainTime).clamp(0.0, 1.0);
    meteorFraction.value = sim.meteorFraction(Side.player);
    if (!_sameBools(me.turrets, turrets)) turrets.assignAll(me.turrets);
    if (!_sameLevels(me.upgrades, upgrades)) upgrades.assignAll(me.upgrades);
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

  static bool _sameLevels(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
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
      _audio?.playCues(cuesFor(e, sim));
      switch (e.type) {
        case SimEventType.meteorImpact:
          _buzz(HapticFeedback.lightImpact);
        case SimEventType.evolved when e.side == Side.enemy:
          _buzz(HapticFeedback.mediumImpact);
        case SimEventType.evolved:
          _battleMusic();
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
      baseHpLeft: me.baseHp / sim.maxHp(Side.player),
    );
    final played = round.value;
    _audio?.sting(result.victory ? Sfx.victory : Sfx.defeat, after: Music.menu);
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
    if (ok) {
      _buzz(HapticFeedback.selectionClick);
      _sfx(Sfx.train);
    } else {
      _denied();
    }
    _refresh();
    return ok;
  }

  bool canAfford(UnitDef u) => gold.value >= u.cost;
  bool get queueFull => queue.length >= data.queueMax;

  /// Opens the ledge picker (the battle waits meanwhile).
  void openTurrets() => _open(BattleOverlay.turrets);

  /// Opens the upgrade menu (the battle waits meanwhile).
  void openUpgrades() => _open(BattleOverlay.upgrades);

  int upgradeLevel(String id) => upgrades[id] ?? 0;

  /// Gold for [id]'s next level, null when maxed.
  int? upgradeCost(String id) => sim.upgradeCost(Side.player, id);

  /// True when there's an upgrade the player can buy right now (lights
  /// the HUD button).
  bool get canUpgrade => data.upgrades.any((u) {
    final c = sim.upgradeCost(Side.player, u.id);
    return c != null && gold.value >= c;
  });

  void buyUpgrade(String id) {
    final ok = sim.buyUpgrade(Side.player, id);
    ok ? _buzz(HapticFeedback.mediumImpact) : _denied();
    _refresh();
  }

  void buildTurret(int slot) {
    final ok = sim.buyTurret(Side.player, slot);
    ok ? _buzz(HapticFeedback.mediumImpact) : _denied();
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
      _denied();
    }
    _refresh();
  }

  /// Evolves when the XP is there. In the last age it shows what's
  /// coming instead.
  void tapEvolve() {
    if (lastEra) {
      _open(BattleOverlay.evolveTeaser);
    } else if (sim.evolve(Side.player)) {
      _buzz(HapticFeedback.heavyImpact);
    } else {
      _denied();
    }
    _refresh();
  }

  /// Testing only (debug builds): gives [side] the XP it needs and
  /// evolves it right away. Long-press the Evolve tile for yourself, the
  /// enemy's health bar for the enemy. Does nothing in release builds.
  void debugEvolve([Side side = Side.player]) {
    if (!kDebugMode) return;
    final st = sim[side];
    final need = sim.evolveXpOf(side);
    if (need == 0) return; // already the last age
    if (st.xp < need) st.xp = need;
    sim.evolve(side);
    _buzz(HapticFeedback.heavyImpact);
    _refresh();
  }

  void toggleSpeed() {
    speed.value = speed.value == 1 ? 2 : 1;
    game.speed = speed.value.toDouble();
  }

  void pan(double dx) => game.panBy(dx);

  void panStart() => game.panStart();

  void panEnd() => game.panEnd();

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
