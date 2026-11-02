import 'dart:ui';

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
    required Sprite cliff,
    required Sprite turret,
    required Sprite turretFire,
  }) : _baseSprite = base,
       _cliffSprite = cliff,
       _turretSprite = turret,
       _turretFireSprite = turretFire,
       super(priority: 5);

  final Side side;
  final BattleSim sim;
  final Sprite _baseSprite;
  final Sprite _cliffSprite;
  final Sprite _turretSprite;
  final Sprite _turretFireSprite;
  late final SpriteComponent _base;
  final List<_TurretView> _turrets = [];

  BaseArt get art => sim.data.baseArt;

  double get drawH => art.height;
  double get drawW => drawH * _baseSprite.srcSize.x / _baseSprite.srcSize.y;
  double get _bottom => Layout.groundY + Layout.baseSink;

  /// Turret width: sized to the ledges when the art says so.
  double get turretW => art.turretW > 0 ? art.turretW * drawW : Layout.turretW;

  /// The picture's left edge in world x, placed so its gate is where
  /// units spawn (the sim's base front).
  double get _artLeft {
    final front = sim.frontOf(side);
    return side == Side.player
        ? front - art.gate * drawW
        : front + art.gate * drawW - drawW;
  }

  /// The picture's left and right edges in world x.
  double get artLeft => _artLeft;
  double get artRight => _artLeft + drawW;

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
    // Drawn over the base's outer edge so the rock runs on without a seam.
    add(_Cliff(_cliffSprite, side, drawH, art.cliffFrom * drawW, drawW));

    final tw = turretW;
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
    return Vector2(p.x, p.y - turretW * 0.7);
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

/// Rock continuing the base outward (left of the player's base, right of
/// the enemy's), the strip repeated with every other copy mirrored.
class _Cliff extends PositionComponent {
  _Cliff(this.sprite, this.side, this.h, this.from, this.baseW);

  final Sprite sprite;
  final Side side;
  final double h;

  /// Where the repeats start, measured from the base's outer edge.
  final double from;
  final double baseW;

  static const double reach = 900;

  @override
  void render(Canvas canvas) {
    final w = h * sprite.srcSize.x / sprite.srcSize.y;
    if (w <= 0) return;
    final size = Vector2(w, h);
    var k = 0;
    for (var edge = from; edge > -reach; edge -= w, k++) {
      // Player: copies run left from `edge`. Enemy: mirrored to the right.
      final mirrored = k.isEven;
      final left = side == Side.player ? edge - w : baseW - edge;
      final flip = side == Side.player ? mirrored : !mirrored;
      canvas.save();
      if (flip) {
        canvas
          ..translate(left + w, -h)
          ..scale(-1, 1);
      } else {
        canvas.translate(left, -h);
      }
      sprite.render(canvas, size: size);
      canvas.restore();
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
