import '../../models/game_data.dart';
import '../sim/battle_sim.dart';

/// Every sound effect in the game. Files live in assets/audio/sfx/ as
/// `<snake_case name>.wav`; replace a file to change a sound.
enum Sfx {
  tap(0.5, 0.04),
  denied(0.6, 0.15),
  train(0.6, 0.05),
  swingLight(0.55, 0.06),
  swingHeavy(0.7, 0.08),
  throwStone(0.5, 0.06),
  catapult(0.7, 0.1),
  bow(0.55, 0.06),
  ballista(0.75, 0.1),
  musket(0.6, 0.07),
  cannon(0.8, 0.12),
  hit(0.45, 0.045),
  death(0.6, 0.08),
  coin(0.35, 0.07),
  baseHit(0.7, 0.3),
  meteorCast(0.8, 0.5),
  meteorImpact(0.8, 0.09),
  volleyCast(0.8, 0.5),
  arrowImpact(0.55, 0.05),
  build(0.7, 0.2),
  sell(0.6, 0.2),
  upgrade(0.7, 0.2),
  evolve(0.9, 1.0),
  victory(0.9, 1.0),
  defeat(0.9, 1.0);

  const Sfx(this.volume, this.minGap);

  /// Base loudness (0–1) before the event's own scaling.
  final double volume;

  /// Seconds before the same sound may play again: a 16-arrow volley or
  /// a big melee shouldn't stack into noise.
  final double minGap;

  String get file {
    final snake = name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
    return 'sfx/$snake.wav';
  }
}

/// One sound to play for a sim event.
class SoundCue {
  const SoundCue(this.sfx, [this.volume = 1]);

  final Sfx sfx;

  /// Scales [Sfx.volume]; the enemy's own actions are a little quieter.
  final double volume;

  @override
  bool operator ==(Object other) => other is SoundCue && other.sfx == sfx && other.volume == volume;

  @override
  int get hashCode => Object.hash(sfx, volume);

  @override
  String toString() => 'SoundCue($sfx, $volume)';
}

/// Which sounds a sim event makes. Pure, so it is unit-tested.
List<SoundCue> cuesFor(SimEvent e, BattleSim sim) {
  final mine = e.side == Side.player;
  final v = mine ? 1.0 : 0.7;
  switch (e.type) {
    case SimEventType.attack:
      final u = sim.unitById(e.unitId);
      if (u == null || u.def.ranged) return const [];
      final heavy = u.def.role == UnitRole.heavy || u.def.role == UnitRole.elite;
      return [SoundCue(heavy ? Sfx.swingHeavy : Sfx.swingLight, v)];
    case SimEventType.projectile:
      final p = sim.projectileById(e.unitId);
      if (p == null) return const [];
      final sfx = switch (p.sprite) {
        'rock' => Sfx.catapult,
        'medieval_bolt' => Sfx.ballista,
        'medieval_arrow' => Sfx.bow,
        'gunpowder_ball' => Sfx.musket,
        'gunpowder_cannonball' => Sfx.cannon,
        _ => Sfx.throwStone,
      };
      return [SoundCue(sfx, v)];
    case SimEventType.hit:
      return [SoundCue(Sfx.hit, v)];
    case SimEventType.kill:
      // The reward goes to e.side: a coin when it's us.
      return [const SoundCue(Sfx.death), if (mine) const SoundCue(Sfx.coin)];
    case SimEventType.baseHit:
      return [SoundCue(Sfx.baseHit, mine ? 1.0 : 0.6)];
    case SimEventType.meteorCast:
      final arrows = sim.eraOf(e.side).meteor.style == 'arrows';
      return [SoundCue(arrows ? Sfx.volleyCast : Sfx.meteorCast, v)];
    case SimEventType.meteorImpact:
      final arrows = e.meteor?.style == 'arrows';
      return [SoundCue(arrows ? Sfx.arrowImpact : Sfx.meteorImpact)];
    case SimEventType.turretBought:
      return mine ? const [SoundCue(Sfx.build)] : const [];
    case SimEventType.turretSold:
      return mine ? const [SoundCue(Sfx.sell)] : const [];
    case SimEventType.upgraded:
      return mine ? const [SoundCue(Sfx.upgrade)] : const [];
    case SimEventType.evolved:
      return [SoundCue(Sfx.evolve, mine ? 1.0 : 0.6)];
    case SimEventType.spawn:
    case SimEventType.gameOver:
      return const [];
  }
}

/// Background music: files in assets/audio/music/<track>.mp3. A missing
/// file just means silence.
class Music {
  Music._();

  static const menu = 'menu';
  static const victory = 'victory';
  static const defeat = 'defeat';

  /// One battle track per age: battle_stone, battle_medieval...
  static String battle(String era) => 'battle_$era';
}
