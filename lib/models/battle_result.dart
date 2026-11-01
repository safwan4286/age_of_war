import 'game_data.dart';

/// What the results screen shows. Passed as the route argument.
class BattleResult {
  const BattleResult({
    required this.difficulty,
    required this.victory,
    required this.stars,
    required this.seconds,
    required this.kills,
    required this.goldEarned,
    required this.xp,
    required this.baseHpLeft,
    this.newBest = false,
  });

  final Difficulty difficulty;
  final bool victory;
  final int stars;
  final double seconds;
  final int kills;
  final int goldEarned;
  final int xp;

  /// 0..1
  final double baseHpLeft;
  final bool newBest;

  BattleResult copyWith({bool? newBest}) => BattleResult(
    difficulty: difficulty,
    victory: victory,
    stars: stars,
    seconds: seconds,
    kills: kills,
    goldEarned: goldEarned,
    xp: xp,
    baseHpLeft: baseHpLeft,
    newBest: newBest ?? this.newBest,
  );

  String get timeLabel {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
