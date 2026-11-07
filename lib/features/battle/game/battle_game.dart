import 'dart:async';
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
import 'components/muzzle_flash.dart';
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
  final Map<String, Sprite> _fx = {};
  final Map<String, SpriteAnimation> _blasts = {};

  /// Era art loading or loaded (current + the next one, so an evolve
  /// never waits on it).
  final Map<int, Future<void>> _eraLoads = {};
  int _bgEra = 0;

  /// Old ages are unloaded once nothing on the field uses them.
  double _gcClock = 0;
  final Set<int> _gcPending = {};

  Vector2 _screen = Vector2.zero();
  double _camX = 0;
  bool _dragging = false;
  double _shake = 0;
  bool _ready = false;
  final _rng = math.Random();

  @override
  Color backgroundColor() => Pal.night;

  double get _zoom => _screen.y <= 0 ? 1 : _screen.y / Layout.viewH;
  double get _viewW => _screen.x / _zoom;
  double get camLeft => _camX - _viewW / 2;

  @override
  Future<void> onLoad() async {
    final data = sim.data;
    await _loadEra(0);
    // The next age loads in the background; it's minutes away.
    unawaited(_loadEra(1));

    final first = data.era(0);
    for (final (name, f, p) in [('sky', 0.2, -30), ('hills', 0.5, -20), ('near', 1.0, -10)]) {
      final place = first.layer(name);
      final layer = BgLayer(
        sprite: Sprite(images.fromCache(Img.bg(first.id, name))),
        factor: f,
        priority: p,
        layerTop: place.top,
        layerH: place.height,
        mirror: place.mirror,
      );
      _layers.add(layer);
      world.add(layer);
    }

    // The sky reddens while meteors are falling.
    world.add(_SkyTint(sim));

    for (final side in Side.values) {
      _placeBase(side);
    }

    camera.viewfinder.anchor = Anchor.center;
    _ready = true;
    _applyCamera();
  }

  /// Where a unit's shot appears (its bow), if the unit says.
  Vector2? _muzzle(SimProjectile p) {
    final d = p.shooter;
    if (d == null || d.muzzleUp <= 0) return null;
    return Vector2(p.startX + p.side.dir * d.muzzleAhead, Layout.groundY - d.muzzleUp);
  }

  /// Loads era [i]'s art and builds its animations and effects.
  Future<void> _loadEra(int i) {
    if (i >= sim.data.eras.length) return Future.value();
    return _eraLoads.putIfAbsent(i, () => _buildEra(i));
  }

  Future<void> _buildEra(int i) async {
    final era = sim.data.era(i);
    await images.loadAll(Img.era(era));
    for (final def in era.units) {
      for (final red in [false, true]) {
        _anims['${def.id}/$red'] = UnitAnims.build(images, def, red: red);
      }
    }
    for (final name in {
      for (final u in era.units)
        if (u.ranged) u.projectile,
      era.turret.projectile,
      era.meteor.sprite,
    }) {
      _fx[name] = Sprite(images.fromCache(Img.fx(name)));
    }
    // Square frames side by side; the count follows the strip.
    final blast = images.fromCache(Img.fx(era.meteor.blast));
    _blasts[era.meteor.blast] = SpriteAnimation.fromFrameData(
      blast,
      SpriteAnimationData.sequenced(
        amount: blast.width ~/ blast.height,
        stepTime: 0.07,
        textureSize: Vector2.all(blast.height.toDouble()),
        loop: false,
      ),
    );
  }

  /// Puts [side]'s base for its current era on the field, replacing the
  /// old one.
  void _placeBase(Side side) {
    final era = sim[side].era;
    final id = sim.data.era(era).id;
    final red = side == Side.enemy;
    _bases.remove(side)?.removeFromParent();
    final base = BaseView(
      side: side,
      sim: sim,
      era: era,
      base: Sprite(images.fromCache(Img.base(id, red: red))),
      cliff: Sprite(images.fromCache(Img.cliff(id, red: red))),
      turret: Sprite(images.fromCache(Img.turret(id, red: red))),
      turretFire: Sprite(images.fromCache(Img.turretFire(id, red: red))),
    );
    _bases[side] = base;
    world.add(base);
  }

  /// A side reached a new age: new base (with a flash), the player's
  /// backdrop cross-fades, and the era after it starts loading.
  Future<void> _evolved(Side side) async {
    final era = sim[side].era;
    await _loadEra(era);
    if (sim[side].era != era) return;
    _placeBase(side);
    world.add(_EvolveFlash(_bases[side]!));
    if (side == Side.player && era != _bgEra) {
      _bgEra = era;
      final e = sim.data.era(era);
      for (final (i, name) in [(0, 'sky'), (1, 'hills'), (2, 'near')]) {
        final place = e.layer(name);
        _layers[i].swap(
          Sprite(images.fromCache(Img.bg(e.id, name))),
          layerTop: place.top,
          layerH: place.height,
          mirror: place.mirror,
        );
      }
    }
    unawaited(_loadEra(era + 1));
  }

  /// Every 2 s: an era both sides have left, with none of its units,
  /// shots or meteors still around (two checks in a row, so blasts and
  /// fades started earlier have finished), has its images freed.
  void _collectOldEras(double dt) {
    _gcClock += dt;
    if (_gcClock < 2) return;
    _gcClock = 0;
    final oldest = math.min(sim[Side.player].era, sim[Side.enemy].era);
    for (final i in _eraLoads.keys.toList()) {
      if (i >= oldest || !_unused(i)) {
        _gcPending.remove(i);
      } else if (!_gcPending.add(i)) {
        _gcPending.remove(i);
        _freeEra(i);
      }
    }
  }

  bool _unused(int i) {
    final era = sim.data.era(i);
    final fx = {
      for (final u in era.units) u.projectile,
      era.turret.projectile,
      era.meteor.sprite,
    };
    return !sim.units.any((u) => u.def.era == era.id) &&
        !sim.projectiles.any((p) => fx.contains(p.sprite)) &&
        !sim.meteors.any((m) => m.sprite == era.meteor.sprite);
  }

  void _freeEra(int i) {
    final era = sim.data.era(i);
    final keep = {
      for (final k in _eraLoads.keys)
        if (k != i) ...Img.era(sim.data.era(k)),
    };
    for (final path in Img.era(era)) {
      if (!keep.contains(path)) images.clear(path);
    }
    for (final def in era.units) {
      _anims.remove('${def.id}/false');
      _anims.remove('${def.id}/true');
    }
    _fx.removeWhere((name, _) => !keep.contains(Img.fx(name)));
    _blasts.removeWhere((name, _) => !keep.contains(Img.fx(name)));
    _eraLoads.remove(i);
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

  /// Where the camera centre rests: the whole player base at the left,
  /// the whole enemy base at the right.
  (double, double) get _rest {
    final half = _viewW / 2;
    final left = (_bases[Side.player]?.artLeft ?? 0) - Layout.camMargin;
    final right = (_bases[Side.enemy]?.artRight ?? sim.data.laneLength) + Layout.camMargin;
    final lo = left + half, hi = right - half;
    return lo >= hi ? ((lo + hi) / 2, (lo + hi) / 2) : (lo, hi);
  }

  /// Where the battle opens: the gate with [Layout.baseShow] of the base
  /// behind it, not the whole castle.
  double _start(double lo, double hi) {
    final left = sim.frontOf(Side.player) - Layout.baseShow - Layout.camMargin;
    return (left + _viewW / 2).clamp(lo, hi).toDouble();
  }

  void panStart() => _dragging = true;

  void panEnd() => _dragging = false;

  /// Drag on the battlefield: [screenDx] in logical pixels. Past either
  /// end the drag meets growing resistance (rubber band); on release the
  /// camera springs back in [update].
  void panBy(double screenDx) {
    final (lo, hi) = _rest;
    var d = -screenDx / _zoom;
    final over = _camX < lo ? lo - _camX : (_camX > hi ? _camX - hi : 0.0);
    final outward = (_camX <= lo && d < 0) || (_camX >= hi && d > 0);
    if (outward) d *= 0.5 * (1 - over / Layout.overscroll).clamp(0.0, 1.0);
    _camX += d;
    _applyCamera();
  }

  void _springBack(double dt) {
    if (_dragging || !_ready) return;
    final (lo, hi) = _rest;
    final target = _camX.clamp(lo, hi).toDouble();
    if ((target - _camX).abs() < 0.5) {
      _camX = target;
    } else {
      _camX += (target - _camX) * math.min(1.0, dt * 12);
    }
  }

  /// Centre the camera on a lane x (minimap / "jump to front").
  void lookAt(double x) {
    _camX = x;
    _applyCamera();
  }

  void _applyCamera() {
    if (_screen.x <= 0 || !_ready) return;
    final (lo, hi) = _rest;
    if (_camX.isInfinite) _camX = _camX < 0 ? _start(lo, hi) : hi;
    _camX = _camX.clamp(lo - Layout.overscroll, hi + Layout.overscroll).toDouble();
    camera.viewfinder.zoom = _zoom;
    var sx = 0.0, sy = 0.0;
    if (_shake > 0) {
      final a = 6 * _shake / 0.25;
      sx = (_rng.nextDouble() * 2 - 1) * a;
      sy = (_rng.nextDouble() * 2 - 1) * a;
    }
    camera.viewfinder.position = Vector2(_camX + sx, Layout.viewTop + Layout.viewH / 2 + sy);
    for (final l in _layers) {
      l.follow(camLeft, _viewW);
    }
  }

  void shake([double seconds = 0.25]) {
    if (screenShake) _shake = math.max(_shake, seconds);
  }

  @override
  void update(double dt) {
    if (!_ready) return;
    _springBack(dt);
    if (frozen) {
      _applyCamera();
      return;
    }
    final step = dt * speed;
    ai.update(step);
    sim.step(step);
    _collectOldEras(step);
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
      final anims = _anims['${u.def.id}/${u.side == Side.enemy}'];
      if (anims == null) continue; // its era is still loading
      final view = UnitView(u, anims);
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
      final turret = p.kind == ProjectileKind.rock;
      final sprite = _fx[p.sprite];
      if (sprite == null) continue;
      final launch = turret ? _bases[p.side]?.launchPos(p.slot) : _muzzle(p);
      final view = ProjectileView(p, sprite, launch: launch);
      if (turret) _bases[p.side]?.fireTurret(p.slot);
      final gun = Img.firearms[p.sprite];
      if (gun != null) {
        world.add(MuzzleFlash(launch ?? Vector2(p.startX, Layout.slingY), dir: p.side.dir.toDouble(), power: gun));
      }
      _shots[p.id] = view;
      world.add(view);
    }
    _shots.removeWhere((id, v) {
      if (flying.contains(id)) return false;
      v.removeFromParent();
      return true;
    });

    for (final m in sim.meteors) {
      if (_falling.contains(m) || sim.time < m.at - m.fallTime) {
        continue;
      }
      final sprite = _fx[m.sprite];
      if (sprite == null) continue;
      _falling.add(m);
      world.add(MeteorView(m, sim, sprite));
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
          final m = e.meteor;
          final anim = _blasts[m?.blast];
          if (anim != null) world.add(BlastView(anim, e.x, size: m!.blastSize));
          shake();
        case SimEventType.evolved:
          _evolved(e.side);
        default:
          break;
      }
    }
  }
}

/// Red wash over the sky (between the sky and hill layers) while a meteor
/// shower is falling; fades in and out.
class _SkyTint extends RectangleComponent {
  _SkyTint(this.sim)
    : super(
        position: Vector2(-4000, Layout.viewTop - 200),
        size: Vector2(12000, Layout.viewH + 400),
        priority: -25,
        paint: Paint()..color = const Color(0x00000000),
      );

  final BattleSim sim;
  double _alpha = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final target = sim.meteors.isNotEmpty ? 0.45 : 0.0;
    _alpha += (target - _alpha) * math.min(1.0, dt * 3);
    paint.color = Color.fromRGBO(150, 30, 20, _alpha);
  }
}

/// White burst over a base that just evolved.
class _EvolveFlash extends RectangleComponent {
  _EvolveFlash(BaseView base)
    : super(
        position: Vector2(base.artLeft - 40, Layout.viewTop),
        size: Vector2(base.artRight - base.artLeft + 80, Layout.viewH),
        priority: 40,
        paint: Paint()..color = const Color(0xCCFFF6D8),
      );

  static const double time = 0.7;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final a = (1 - _t / time).clamp(0.0, 1.0);
    paint.color = Color.fromRGBO(255, 246, 216, 0.8 * a * a);
    if (_t >= time) removeFromParent();
  }
}
