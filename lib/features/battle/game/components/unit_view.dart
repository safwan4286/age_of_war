import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../../models/game_data.dart';
import '../../../../resources/assets.dart';
import '../../../../services/sim/battle_sim.dart';
import '../world_layout.dart';

/// The four animations for one unit type and colour, built once and
/// shared by every unit of that type (tickers live in the components).
class UnitAnims {
  UnitAnims._(this.byState, this.frameSize, this.drawScale);

  final Map<UnitState, SpriteAnimation> byState;
  final Vector2 frameSize;
  final double drawScale;

  Vector2 get drawSize => frameSize * drawScale;

  static UnitAnims build(Images images, UnitDef def, {required bool red}) {
    final frame = Vector2(def.frameW.toDouble(), def.frameH.toDouble());
    SpriteAnimation anim(String name, double Function(int frames) step, bool loop) {
      final frames = def.frameCount(name);
      return SpriteAnimation.fromFrameData(
          images.fromCache(Img.unit(def.sprite, name, red: red)),
          SpriteAnimationData.sequenced(
            amount: frames,
            stepTime: step(frames),
            textureSize: frame,
            loop: loop,
          ),
        );
    }
    return UnitAnims._({
      UnitState.idle: anim('idle', (_) => def.frameTime('idle', 0.16), true),
      UnitState.walking: anim('walk', (_) => def.frameTime('walk', 0.1), true),
      // One swing per attack, so the loop stays in step with the hits.
      UnitState.attacking: anim('attack', (n) => def.attackEvery / n, true),
      UnitState.dying: anim('die', (n) => BattleSim.dyingTime / n, false),
    }, frame, def.drawScale);
  }
}

/// Mirrors one [SimUnit]: position, animation, hit flash, health bar.
class UnitView extends PositionComponent {
  UnitView(this.unit, this.anims)
    : super(
        position: Vector2(unit.x, Layout.groundY),
        // Enemies draw behind, so a clash reads left-to-right.
        priority: unit.side == Side.player ? 12 : 11,
      );

  final SimUnit unit;
  final UnitAnims anims;
  late final SpriteAnimationGroupComponent<UnitState> _sprite;
  double _flash = 0;

  static final _barBack = Paint()..color = const Color(0xCC0F1720);
  static final _barPlayer = Paint()..color = const Color(0xFF7BC86C);
  static final _barEnemy = Paint()..color = const Color(0xFFD9553B);
  static const _white = ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcATop);

  double get _drawH => anims.drawSize.y;

  @override
  Future<void> onLoad() async {
    _sprite = SpriteAnimationGroupComponent<UnitState>(
      animations: anims.byState,
      current: unit.state,
      size: anims.drawSize,
      anchor: Anchor.bottomCenter,
    );
    // Art faces right; enemies walk left.
    if (unit.side == Side.enemy) _sprite.flipHorizontally();
    add(_sprite);
  }

  void flash() => _flash = 0.08;

  @override
  void update(double dt) {
    super.update(dt);
    x = unit.x;
    if (_sprite.current != unit.state) _sprite.current = unit.state;
    if (_flash > 0) {
      _flash -= dt;
      _sprite.paint.colorFilter = _flash > 0 ? _white : null;
    }
    if (unit.state == UnitState.dying) {
      final t = unit.dyingFor / BattleSim.dyingTime;
      _sprite.opacity = (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!unit.alive || unit.hp >= unit.def.hp) return;
    const w = 34.0, h = 5.0;
    final top = -_drawH * 0.78;
    canvas.drawRect(Rect.fromLTWH(-w / 2 - 1, top - 1, w + 2, h + 2), _barBack);
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, top, w * unit.hpFraction, h),
      unit.side == Side.player ? _barPlayer : _barEnemy,
    );
  }
}
