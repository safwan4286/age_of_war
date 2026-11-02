import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/game_data.dart';
import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../services/responsiveness/device_manager.dart';
import '../../../widgets/game_ui.dart';
import '../battle_controller.dart';

/// Bottom-left corner: compact unit cards. The training queue lives on the
/// cards themselves: a count badge per unit and a progress bar on the one
/// being trained, so no separate queue box.
class HudUnits extends GetView<BattleController> {
  const HudUnits({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: EdgeInsets.fromLTRB(10.sp, 0, 0, 6.sp),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final u in c.data.units) ...[
            UnitCard(def: u),
            SizedBox(width: 4.sp),
          ],
        ],
      ),
    );
  }
}

/// One unit in the shop: portrait, cost, how many are queued and the
/// training progress. Shakes when it can't be bought; long-press for stats.
class UnitCard extends StatefulWidget {
  const UnitCard({super.key, required this.def});

  final UnitDef def;

  @override
  State<UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends State<UnitCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  BattleController get c => Get.find<BattleController>();

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap() {
    if (!c.train(widget.def.id)) _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.def;
    final tip = '${u.name}\nHP ${u.hp.round()} · DMG ${u.damage.round()}'
        '${u.ranged ? ' · RANGED' : ''}'
        '${u.auraBonus > 0 ? ' · +${(u.auraBonus * 100).round()}% to allies' : ''}';
    final w = 56.sp, h = 64.sp, r = 11.sp;
    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.longPress,
      textStyle: AppTheme.body(14),
      decoration: BoxDecoration(
        color: Pal.stoneBottom,
        borderRadius: BorderRadius.circular(10.sp),
        border: Border.all(color: Pal.amber, width: 2.sp),
      ),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(math.sin(_shake.value * math.pi * 6) * 5.sp * (1 - _shake.value), 0),
          child: child,
        ),
        child: Obx(() {
          final ok = c.canAfford(u) && !c.queueFull && !c.popFull;
          final queued = c.queue.where((id) => id == u.id).length;
          final training = c.queue.isNotEmpty && c.queue.first == u.id;
          return Semantics(
            button: true,
            label: '${u.name}, ${u.cost} gold${queued > 0 ? ', $queued in training' : ''}',
            enabled: ok,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _tap,
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(color: ok ? Pal.amber : Pal.ink, width: 2.5.sp),
                        color: Pal.stoneBottom,
                        boxShadow: [BoxShadow(color: Pal.ink.withValues(alpha: 0.5), offset: Offset(0, 2.sp))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(r - 2.5.sp),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF8FB8D8), Color(0xFF5C86A8)],
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColorFiltered(
                                      colorFilter: ok
                                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                          : const ColorFilter.matrix(_grey),
                                      // Anchored at the top so heads are never cut.
                                      child: Image.asset(
                                        UiImg.unitCard(u.sprite),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                    // Training: a dark shade that sweeps away clockwise.
                                    if (training) _Sweep(progress: c.trainFraction.value),
                                  ],
                                ),
                              ),
                            ),
                            // Cost strip; the training bar runs along its top.
                            Container(
                              height: 16.sp,
                              color: Pal.ink,
                              child: Stack(
                                children: [
                                  if (training)
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: _SmoothBar(progress: c.trainFraction.value),
                                    ),
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const GameImage(UiImg.gold, size: 10),
                                        SizedBox(width: 2.sp),
                                        Text(
                                          '${u.cost}',
                                          style: AppTheme.display(12, color: ok ? Pal.amber : Pal.muted, outlined: false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (queued > 0)
                      Positioned(
                        left: -5.sp,
                        top: -6.sp,
                        child: Container(
                          width: 19.sp,
                          height: 19.sp,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: training ? Pal.leaf : Pal.amber,
                            border: Border.all(color: Pal.ink, width: 2.sp),
                          ),
                          child: Text('$queued', style: AppTheme.display(12)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// The HUD refreshes 10 times a second; these widgets animate between
/// updates so training progress moves smoothly, not in steps.
class _SmoothBar extends StatelessWidget {
  const _SmoothBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 110),
      builder: (context, v, _) => FractionallySizedBox(
        widthFactor: v,
        child: Container(
          height: 4.sp,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF9FE06A), Color(0xFF5BAE2F)]),
            boxShadow: [BoxShadow(color: Pal.leaf.withValues(alpha: 0.8), blurRadius: 4.sp)],
          ),
        ),
      ),
    );
  }
}

class _Sweep extends StatelessWidget {
  const _Sweep({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 110),
      builder: (context, v, _) => CustomPaint(painter: _SweepPainter(v)),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v >= 1) return;
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    const top = -math.pi / 2;
    final done = 2 * math.pi * v;
    // Remaining part of the clock stays dark; the edge gets a bright line.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      top + done,
      2 * math.pi - done,
      true,
      Paint()..color = const Color(0x8C000000),
    );
    final edge = Offset(c.dx + r * math.cos(top + done), c.dy + r * math.sin(top + done));
    canvas.drawLine(
      c,
      edge,
      Paint()
        ..color = const Color(0xCCFFF3D6)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.v != v;
}

/// Greyscale for units you can't buy right now.
const List<double> _grey = [
  0.33, 0.33, 0.33, 0, 0,
  0.33, 0.33, 0.33, 0, 0,
  0.33, 0.33, 0.33, 0, 0,
  0, 0, 0, 0.8, 0,
];
