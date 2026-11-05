import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../../models/game_data.dart';
import '../../../../resources/assets.dart';
import '../../../../services/sim/battle_sim.dart';
import '../../../../services/sim/swing.dart';
import '../world_layout.dart';

/// The four animations for one unit type and colour, built once and
/// shared by every unit of that type (tickers live in the components).
class UnitAnims {
  UnitAnims._(this.byState, this.frameSize, this.drawScale, this.swing);

  final Map<UnitState, SpriteAnimation> byState;
  final Vector2 frameSize;
  final double drawScale;

  /// Attack frame timing (the attack strip is driven frame by frame).
  final Swing swing;

  Vector2 get drawSize => frameSize * drawScale;

  static UnitAnims build(Images images, UnitDef def, {required bool red}) {
    final frame = Vector2(def.frameW.toDouble(), def.frameH.toDouble());
    SpriteAnimation anim(String name, double Function(int frames) step, bool loop) {
      final frames = def.frameCount(name);
      final image = images.fromCache(Img.unit(def, name, red: red));
      return SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: frames,
            // Long animations are stored as grids (a strip can't pass
            // 4096 px); one row for the old strips.
            amountPerRow: image.width ~/ def.frameW,
            stepTime: step(frames),
            textureSize: frame,
            loop: loop,
          ),
        );
    }
    return UnitAnims._({
      UnitState.idle: anim('idle', (_) => def.frameTime('idle', 0.16), true),
      UnitState.walking: anim('walk', (_) => def.frameTime('walk', 0.1), true),
      // Driven by [Swing] in UnitView, not by the ticker.
      UnitState.attacking: anim('attack', (n) => def.attackEvery / n, true),
      UnitState.dying: anim('die', (n) => BattleSim.dyingTime / n, false),
    }, frame, def.drawScale, Swing(def));
  }
}

/// Mirrors one [SimUnit]: position, animation, hit flash. Its health bar
/// is a separate component on a top layer, so other units never cover it.
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
  late final HealthBar _bar = HealthBar(unit, anims);
  double _flash = 0;
  double _lastCooldown = 0;
  double? _sinceHit;

  static const _white = ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcATop);

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

  @override
  void onMount() {
    super.onMount();
    parent?.add(_bar);
  }

  @override
  void onRemove() {
    _bar.removeFromParent();
    super.onRemove();
  }

  /// While attacking, the frame comes from the sim's clock so the impact
  /// frame shows exactly when the blow lands.
  void _syncSwing(double dt) {
    final attacking = unit.state == UnitState.attacking;
    _sprite.playing = !attacking;
    if (!attacking) return;
    // The cooldown jumps up when a blow lands.
    if (unit.cooldown > _lastCooldown + 1e-6) {
      _sinceHit = 0;
    } else if (_sinceHit != null) {
      _sinceHit = _sinceHit! + dt;
    }
    _lastCooldown = unit.cooldown;
    _sprite.animationTicker?.currentIndex = anims.swing.frameAt(
      toHit: math.max(0, unit.cooldown),
      sinceHit: _sinceHit,
    );
  }

  void flash() {
    _flash = 0.08;
    _bar.show();
  }

  @override
  void update(double dt) {
    super.update(dt);
    x = unit.x;
    if (_sprite.current != unit.state) {
      _sprite.current = unit.state;
      _sinceHit = null;
      _lastCooldown = unit.cooldown;
    }
    _syncSwing(dt);
    if (_flash > 0) {
      _flash -= dt;
      _sprite.paint.colorFilter = _flash > 0 ? _white : null;
    }
    if (unit.state == UnitState.dying) {
      final t = unit.dyingFor / BattleSim.dyingTime;
      _sprite.opacity = (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    }
  }
}

/// Health bar over a unit's head, Age of War style: outlined, shows once
/// the unit is hurt, with a pale "recent damage" trail that drains after
/// the real value.
class HealthBar extends PositionComponent {
  HealthBar(this.unit, this.anims) : super(priority: 34, anchor: Anchor.bottomCenter);

  final SimUnit unit;
  final UnitAnims anims;
  double _shown = 1;
  double _trail = 1;
  double _visible = 0;

  static const double w = 46, h = 7;
  static final _back = Paint()..color = const Color(0xFF1E140C);
  static final _ink = Paint()
    ..color = const Color(0xFF2B1B10)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _trailPaint = Paint()..color = const Color(0xFFFFF3D6);
  static final _player = Paint()..color = const Color(0xFF7CC843);
  static final _enemy = Paint()..color = const Color(0xFFE0482F);

  void show() => _visible = 1;

  double get _headY => unit.def.headY > 0 ? unit.def.headY : anims.drawSize.y * 0.8;

  @override
  void update(double dt) {
    super.update(dt);
    position.setValues(unit.x, Layout.groundY - _headY - 8);
    final v = unit.hpFraction;
    _shown = v;
    // The trail waits a moment, then drains to the real value.
    if (_trail > v) {
      _trail = (_trail - dt * 0.6).clamp(v, 1.0);
    } else {
      _trail = v;
    }
    if (v < 1 && unit.alive) _visible = 1;
    if (!unit.alive) _visible = (_visible - dt * 4).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    if (_visible <= 0) return;
    final a = (_visible * 255).round();
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(-w / 2, -h, w, h), const Radius.circular(h / 2));
    canvas.saveLayer(r.outerRect.inflate(2), Paint()..color = Color.fromARGB(a, 255, 255, 255));
    canvas.drawRRect(r, _back);
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(Rect.fromLTWH(-w / 2, -h, w * _trail, h), _trailPaint);
    canvas.drawRect(Rect.fromLTWH(-w / 2, -h, w * _shown, h), unit.side == Side.player ? _player : _enemy);
    canvas.restore();
    canvas.drawRRect(r, _ink);
    canvas.restore();
  }
}
