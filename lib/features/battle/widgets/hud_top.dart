import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../services/sim/battle_sim.dart';
import '../../../services/responsiveness/device_manager.dart';
import '../../../widgets/game_ui.dart';
import '../battle_controller.dart';

/// Compact top HUD, Age of War style: thin health bars along the top edge,
/// small special tiles + XP bar + gold/population on the left, round speed
/// and pause buttons on the right. The sky in between stays clear.
class HudTop extends GetView<BattleController> {
  const HudTop({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: EdgeInsets.only(top: 6.sp),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() => _Health(value: c.playerHp.value, color: Pal.leaf, who: 'Your base')),
                  SizedBox(height: 6.sp),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Obx(
                                () => SpecialTile(
                                  icon: UiImg.special(c.playerEra),
                                  ready: c.meteorReady,
                                  fill: c.meteorFraction.value,
                                  semantics: c.meteorReady
                                      ? '${c.playerEra.meteor.name} ready'
                                      : '${c.playerEra.meteor.name} charging, ${(c.meteorFraction.value * 100).floor()} percent',
                                  onTap: c.castMeteor,
                                ),
                              ),
                              SizedBox(width: 6.sp),
                              Obx(
                                () => SpecialTile(
                                  icon: UiImg.evolve(c.playerEra),
                                  ready: c.canEvolve,
                                  fill: c.evolveFraction,
                                  semantics: c.lastEra
                                      ? '${c.playerEra.name}, the last age for now'
                                      : c.canEvolve
                                      ? 'Evolve to the next age'
                                      : 'Evolve needs ${c.evolveXp} XP',
                                  onTap: c.tapEvolve,
                                  // Testing: long-press evolves instantly.
                                  onLongPress: kDebugMode ? c.debugEvolve : null,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.sp),
                          Obx(
                            () => Semantics(
                              label: c.lastEra
                                  ? '${c.xp.value} experience'
                                  : '${c.xp.value} of ${c.evolveXp} experience',
                              excludeSemantics: true,
                              child: GameBar(
                                value: c.evolveFraction,
                                color: Pal.xp,
                                label: c.lastEra ? 'MAX AGE' : '${c.xp.value} XP',
                                width: 2 * SpecialTile.side + 6,
                                height: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 8.sp),
                      Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Chip(
                              icon: Icons.circle,
                              image: UiImg.gold,
                              text: '${c.gold.value}',
                              color: Pal.amber,
                              semantics: '${c.gold.value} gold',
                            ),
                            SizedBox(height: 4.sp),
                            _Chip(
                              icon: Icons.groups_rounded,
                              text: '${c.population.value}/${c.popCap}',
                              color: c.popFull ? Pal.ember : Pal.cream,
                              semantics: '${c.population.value} of ${c.popCap} units',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
          SizedBox(width: 16.sp),
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Testing: long-press the enemy's bar to evolve the enemy.
                  GestureDetector(
                    onLongPress: kDebugMode ? () => c.debugEvolve(Side.enemy) : null,
                    child: Obx(
                      () => _Health(
                        value: c.enemyHp.value,
                        color: Pal.ember,
                        who: 'Enemy base',
                        reverse: true,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.sp),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => RoundIconButton(
                          icon: Icons.fast_forward_rounded,
                          semantics: 'Battle speed ${c.speed.value} times',
                          onTap: c.toggleSpeed,
                          active: c.speed.value > 1,
                          badge: c.speed.value > 1 ? '${c.speed.value}x' : null,
                        ),
                      ),
                      SizedBox(width: 8.sp),
                      RoundIconButton(icon: Icons.pause_rounded, semantics: 'Pause', onTap: c.pause),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

/// Thin health bar along the top edge.
class _Health extends StatelessWidget {
  const _Health({required this.value, required this.color, required this.who, this.reverse = false});

  final double value;
  final Color color;
  final String who;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).ceil().clamp(0, 100);
    return Semantics(
      label: '$who health $pct percent',
      excludeSemantics: true,
      child: GameBar(value: value, color: color, label: '$pct%', width: 230, height: 14, reverse: reverse),
    );
  }
}

/// Dark pill: icon + number (gold, population).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.color,
    required this.semantics,
    this.image,
  });

  final IconData icon;
  final String? image;
  final String text;
  final Color color;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        width: 84.sp,
        height: 22.sp,
        padding: EdgeInsets.symmetric(horizontal: 6.sp),
        decoration: BoxDecoration(
          color: Pal.shade,
          borderRadius: BorderRadius.circular(13.sp),
          border: Border.all(color: Pal.ink, width: 2.sp),
        ),
        child: Row(
          children: [
            if (image != null)
              GameImage(image!, size: 15)
            else
              Icon(icon, size: 15.sp, color: Pal.muted),
            SizedBox(width: 5.sp),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text, style: AppTheme.display(15, color: color)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stone tile for a special (meteor, evolve): the icon, a charge
/// fill rising from the bottom, and a pulsing gold glow when ready.
class SpecialTile extends StatefulWidget {
  const SpecialTile({
    super.key,
    required this.icon,
    required this.ready,
    required this.fill,
    required this.semantics,
    required this.onTap,
    this.onLongPress,
  });

  /// Design units.
  static const double side = 46;

  final String icon;
  final bool ready;
  final double fill;
  final String semantics;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<SpecialTile> createState() => _SpecialTileState();
}

class _SpecialTileState extends State<SpecialTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SpecialTile.side.sp;
    final r = 12.sp;
    return Semantics(
      button: true,
      label: widget.semantics,
      enabled: widget.ready,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: widget.ready ? Pal.amber : Pal.ink, width: 2.5.sp),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Pal.stoneTop, Pal.stoneBottom],
              ),
              boxShadow: [
                BoxShadow(color: Pal.ink.withValues(alpha: 0.5), offset: Offset(0, 2.sp)),
                if (widget.ready)
                  BoxShadow(
                    color: Pal.amber.withValues(alpha: 0.35 + 0.4 * _pulse.value),
                    blurRadius: (8 + 8 * _pulse.value).sp,
                  ),
              ],
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r - 2.5.sp),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!widget.ready)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: widget.fill.clamp(0.0, 1.0),
                      widthFactor: 1,
                      child: ColoredBox(color: Pal.amber.withValues(alpha: 0.3)),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(6.sp),
                  child: GameImage(widget.icon, opacity: widget.ready ? 1 : 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round gold/stone button with a Material icon (speed, pause).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.semantics,
    required this.onTap,
    this.active = false,
    this.badge,
    this.size = 38,
  });

  final IconData icon;
  final String semantics;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size.sp;
    final tone = active ? GameTone.gold : GameTone.stone;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // At least 48 dp to touch even when drawn smaller.
        child: SizedBox(
          width: s < 48 ? 48 : s,
          height: s < 48 ? 48 : s,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Pal.ink, width: 2.5.sp),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [tone.top, tone.bottom],
                    ),
                    boxShadow: [BoxShadow(color: tone.rim, offset: Offset(0, 3.sp))],
                  ),
                  child: Icon(icon, size: s * 0.6, color: Pal.cream, shadows: AppTheme.outline(s * 0.4)),
                ),
                if (badge != null)
                  Positioned(
                    right: -6.sp,
                    bottom: -4.sp,
                    child: Text(badge!, style: AppTheme.display(13, color: Pal.amber)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
