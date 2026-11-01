import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../../../../models/game_data.dart';
import '../../../../services/sim/battle_sim.dart';
import '../world_layout.dart';

/// A base at one end of the lane, with a turret on each built ledge.
///
/// Where the gate and the ledges sit on the picture comes from
/// `units.json` (base.art), so new base art only needs new numbers. The
/// art faces right (toward the lane); the enemy's copy is mirrored.
class BaseView extends PositionComponent {
  BaseView({
    required this.side,
    required this.sim,
    required Sprite base,
    required Sprite turret,
    required Sprite turretFire,
  }) : _baseSprite = base,
       _turretSprite = turret,
       _turretFireSprite = turretFire,
       super(priority: 5);

  final Side side;
  final BattleSim sim;
  final Sprite _baseSprite;
  final Sprite _turretSprite;
  final Sprite _turretFireSprite;
  late final SpriteComponent _base;
  final List<_TurretView> _turrets = [];

  BaseArt get art => sim.data.baseArt;

  double get drawH => art.height;
  double get drawW => drawH * _baseSprite.srcSize.x / _baseSprite.srcSize.y;
  double get _bottom => Layout.groundY + Layout.baseSink;

  /// The picture's left edge in world x, placed so its gate is where
  /// units spawn (the sim's base front).
  double get _artLeft {
    final front = sim.frontOf(side);
    return side == Side.player
        ? front - art.gate * drawW
        : front + art.gate * drawW - drawW;
  }

  /// World position of ledge [slot]: where its turret stands.
  Vector2 slotPos(int slot) {
    final (fx, fy) = art.slots[slot.clamp(0, art.slots.length - 1)];
    final x = side == Side.player
        ? _artLeft + fx * drawW
        : _artLeft + (1 - fx) * drawW;
    return Vector2(x, _bottom - drawH + fy * drawH);
  }

  @override
  Future<void> onLoad() async {
    position = Vector2(_artLeft, _bottom);
    _base = SpriteComponent(
      sprite: _baseSprite,
      size: Vector2(drawW, drawH),
      anchor: Anchor.bottomLeft,
    );
    if (side == Side.enemy) {
      // Mirror around the picture's centre so it spans the same x range.
      _base
        ..anchor = Anchor.bottomCenter
        ..position = Vector2(drawW / 2, 0)
        ..flipHorizontally();
    }
    add(_base);

    final tw = Layout.turretW;
    final th = tw * _turretSprite.srcSize.y / _turretSprite.srcSize.x;
    final slots = sim[side].turrets.length;
    for (var i = 0; i < slots; i++) {
      final t = _TurretView(_turretSprite, _turretFireSprite, Vector2(tw, th))
        ..position = slotPos(i) - position;
      if (side == Side.enemy) t.flipHorizontally();
      _turrets.add(t);
      add(t);
    }
  }

  /// Quick squash when the base takes a hit.
  void hit() {
    if (_base.children.whereType<ScaleEffect>().isNotEmpty) return;
    _base.add(
      ScaleEffect.by(
        Vector2(1.02, 0.98),
        EffectController(duration: 0.06, reverseDuration: 0.1, curve: Curves.easeOut),
      ),
    );
  }

  /// Shows ledge [slot]'s catapult in its thrown pose for a moment.
  void fireTurret(int slot) {
    if (slot >= 0 && slot < _turrets.length) _turrets[slot].fire();
  }

  /// Where a rock leaves the catapult on ledge [slot].
  Vector2 launchPos(int slot) {
    final p = slotPos(slot);
    return Vector2(p.x, p.y - Layout.turretW * 0.7);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final built = sim[side].turrets;
    for (var i = 0; i < _turrets.length && i < built.length; i++) {
      _turrets[i].isVisible = built[i];
    }
  }
}

class _TurretView extends SpriteComponent with HasVisibility {
  _TurretView(this._idle, this._fired, Vector2 size)
    : super(sprite: _idle, size: size, anchor: Anchor.bottomCenter);

  final Sprite _idle;
  final Sprite _fired;
  double _firedFor = 0;

  void fire() {
    _firedFor = 0.35;
    sprite = _fired;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_firedFor <= 0) return;
    _firedFor -= dt;
    if (_firedFor <= 0) sprite = _idle;
  }
}
