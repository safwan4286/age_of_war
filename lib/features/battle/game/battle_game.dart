import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../services/sim/battle_sim.dart';
import '../../../services/sim/enemy_ai.dart';
import 'components/base_view.dart';
import 'components/bg_layer.dart';
import 'components/floating_text.dart';
import 'components/meteor_view.dart';
import 'components/projectile_view.dart';
import 'components/unit_view.dart';
import 'world_layout.dart';

/// The battle's view. It owns no rules: each frame it steps [sim] and
/// [ai], then makes the world's components match the sim's state.
class BattleGame extends FlameGame {
  BattleGame({
    required this.sim,
    required this.ai,
    required this.onTick,
    required this.onEvents,
    this.damageNumbers = true,
    this.screenShake = true,
  });

  final BattleSim sim;
  final EnemyAi ai;

  /// After every sim step, with the scaled dt.
  final void Function(double dt) onTick;

  /// Everything the sim reported this frame (sounds, haptics, game over).
  final void Function(List<SimEvent> events) onEvents;

  bool damageNumbers;
  bool screenShake;

  /// Stops the sim and every animation, but keeps drawing (pause menu,
  /// tutorial, the beat after game over).
  bool frozen = false;

  /// 1x or 2x battle speed.
  double speed = 1;

  final Map<String, UnitAnims> _anims = {};
  final Map<int, UnitView> _units = {};
  final Map<int, ProjectileView> _shots = {};
  final Set<MeteorImpact> _falling = {};
  final Map<Side, BaseView> _bases = {};
  final List<BgLayer> _layers = [];
  late final SpriteAnimation _blast;
  late final Sprite _stone, _rock, _meteor;

  Vector2 _screen = Vector2.zero();
  double _camX = 0;
  double _shake = 0;
  bool _ready = false;
  final _rng = math.Random();

  @override
  Color backgroundColor() => Pal.night;

  double get _zoom => _screen.y <= 0 ? 1 : _screen.y / Layout.worldH;
  double get _viewW => _screen.x / _zoom;
  double get camLeft => _camX - _viewW / 2;

  @override
  Future<void> onLoad() async {
    final data = sim.data;
    await images.loadAll(Img.all(data.units.map((u) => u.sprite).toSet()));

    for (final def in data.units) {
      for (final red in [false, true]) {
        _anims['${def.id}/$red'] = UnitAnims.build(images, def, red: red);
      }
    }
    _stone = Sprite(images.fromCache(Img.stone));
    _rock = Sprite(images.fromCache(Img.rock));
    _meteor = Sprite(images.fromCache(Img.meteor));
    _blast = SpriteAnimation.fromFrameData(
      images.fromCache(Img.blast),
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.07,
        textureSize: Vector2.all(64),
        loop: false,
      ),
    );

    for (final (img, f, p) in [
      (Img.bgSky, 0.2, -30),
      (Img.bgHills, 0.5, -20),
      (Img.bgNear, 1.0, -10),
    ]) {
      final layer = BgLayer(
        sprite: Sprite(images.fromCache(img)),
        factor: f,
        priority: p,
      );
      _layers.add(layer);
      world.add(layer);
    }

    for (final side in Side.values) {
      final red = side == Side.enemy;
      final base = BaseView(
        side: side,
        sim: sim,
        base: Sprite(images.fromCache(Img.base(red: red))),
        turret: Sprite(images.fromCache(Img.turret(red: red))),
        turretFire: Sprite(images.fromCache(Img.turretFire(red: red))),
      );
      _bases[side] = base;
      world.add(base);
    }

    camera.viewfinder.anchor = Anchor.center;
    _ready = true;
    _applyCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final first = _screen.x == 0;
    _screen = size.clone();
    // Start looking at our own base.
    if (first) _camX = -double.infinity;
    _applyCamera();
  }

  /// Drag on the battlefield: [screenDx] in logical pixels.
  void panBy(double screenDx) {
    _camX -= screenDx / _zoom;
    _applyCamera();
  }

  /// Centre the camera on a lane x (minimap / "jump to front").
  void lookAt(double x) {
    _camX = x;
    _applyCamera();
  }

  void _applyCamera() {
    if (_screen.x <= 0) return;
    final lane = sim.data.laneLength;
    final half = _viewW / 2;
    final lo = half - Layout.camMargin;
    final hi = lane - half + Layout.camMargin;
    _camX = lo >= hi ? lane / 2 : _camX.clamp(lo, hi).toDouble();
    if (!_ready) return;
    camera.viewfinder.zoom = _zoom;
    var sx = 0.0, sy = 0.0;
    if (_shake > 0) {
      final a = 6 * _shake / 0.25;
      sx = (_rng.nextDouble() * 2 - 1) * a;
      sy = (_rng.nextDouble() * 2 - 1) * a;
    }
    camera.viewfinder.position = Vector2(_camX + sx, Layout.worldH / 2 + sy);
    for (final l in _layers) {
      l.follow(camLeft);
    }
  }

  void shake([double seconds = 0.25]) {
    if (screenShake) _shake = math.max(_shake, seconds);
  }

  @override
  void update(double dt) {
    if (!_ready || frozen) return;
    final step = dt * speed;
    ai.update(step);
    sim.step(step);
    final events = sim.drainEvents();
    _sync();
    _show(events);
    super.update(step);
    if (_shake > 0) _shake = math.max(0, _shake - dt);
    _applyCamera();
    onTick(step);
    if (events.isNotEmpty) onEvents(events);
  }

  void _sync() {
    final alive = <int>{};
    for (final u in sim.units) {
      alive.add(u.id);
      if (_units.containsKey(u.id)) continue;
      final view = UnitView(u, _anims['${u.def.id}/${u.side == Side.enemy}']!);
      _units[u.id] = view;
      world.add(view);
    }
    _units.removeWhere((id, v) {
      if (alive.contains(id)) return false;
      v.removeFromParent();
      return true;
    });

    final flying = <int>{};
    for (final p in sim.projectiles) {
      flying.add(p.id);
      if (_shots.containsKey(p.id)) continue;
      final rock = p.kind == ProjectileKind.rock;
      final view = ProjectileView(
        p,
        rock ? _rock : _stone,
        launch: rock ? _bases[p.side]?.launchPos(p.slot) : null,
      );
      if (rock) _bases[p.side]?.fireTurret(p.slot);
      _shots[p.id] = view;
      world.add(view);
    }
    _shots.removeWhere((id, v) {
      if (flying.contains(id)) return false;
      v.removeFromParent();
      return true;
    });

    for (final m in sim.meteors) {
      if (_falling.contains(m) || sim.time < m.at - MeteorView.fallTime) {
        continue;
      }
      _falling.add(m);
      world.add(MeteorView(m, sim, _meteor));
    }
    _falling.retainWhere(sim.meteors.contains);
  }

  void _show(List<SimEvent> events) {
    for (final e in events) {
      switch (e.type) {
        case SimEventType.hit:
          _units[e.unitId]?.flash();
          if (damageNumbers) {
            world.add(
              FloatingText(
                e.amount.round().toString(),
                Vector2(e.x, Layout.groundY - 90),
                color: Pal.cream,
                size: 12,
              ),
            );
          }
        case SimEventType.kill:
          if (e.side == Side.player) {
            world.add(
              FloatingText('+${e.amount.round()}', Vector2(e.x, Layout.groundY - 110)),
            );
          }
        case SimEventType.baseHit:
          _bases[e.side]?.hit();
          if (e.side == Side.player) shake(0.12);
        case SimEventType.meteorImpact:
          world.add(BlastView(_blast, e.x));
          shake();
        default:
          break;
      }
    }
  }
}
