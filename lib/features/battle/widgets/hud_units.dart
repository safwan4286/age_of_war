import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/game_data.dart';
import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../widgets/pixel_box.dart';
import '../battle_controller.dart';

/// Bottom-left corner: the unit cards with the training queue beside them.
class HudUnits extends GetView<BattleController> {
  const HudUnits({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final u in c.data.units) ...[
            UnitCard(def: u),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          const _QueueStrip(),
        ],
      ),
    );
  }
}

/// One unit in the shop. Shakes when it can't be bought; long-press for
/// stats.
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
    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.longPress,
      textStyle: AppTheme.body(14),
      decoration: BoxDecoration(
        color: Pal.ink,
        border: Border.all(color: Pal.amber, width: 2),
      ),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(math.sin(_shake.value * math.pi * 6) * 5 * (1 - _shake.value), 0),
          child: child,
        ),
        child: Obx(() {
          final ok = c.canAfford(u) && !c.queueFull && !c.popFull;
          return Semantics(
            button: true,
            label: '${u.name}, ${u.cost} gold',
            enabled: ok,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _tap,
              child: Container(
                width: 62,
                height: 68,
                decoration: BoxDecoration(
                  color: ok ? const Color(0xE630475F) : const Color(0xCC24364A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ok ? Pal.amber : Pal.ink, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PixelImage(UiImg.unitIcon(u.sprite), size: 40, opacity: ok ? 1 : 0.45),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PixelImage(UiImg.gold, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          '${u.cost}',
                          style: AppTheme.display(12, color: ok ? Pal.amber : Pal.muted),
                        ),
                      ],
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

class _QueueStrip extends GetView<BattleController> {
  const _QueueStrip();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      final q = c.queue;
      return Semantics(
        label: q.isEmpty ? 'Training queue empty' : 'Training ${q.length} units',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xB30F1720),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUEUE ${q.length}/${c.data.queueMax}', style: AppTheme.display(9, color: Pal.muted)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < c.data.queueMax; i++)
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: Pal.ink,
                        border: Border.all(
                          color: i == 0 && q.isNotEmpty ? Pal.amber : Pal.panelHi,
                          width: 1.5,
                        ),
                      ),
                      child: i < q.length ? PixelImage(UiImg.unitIcon(c.data.unit(q[i]).sprite)) : null,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              PixelBar(value: c.trainFraction.value, color: Pal.amber, width: 20.0 * 5, height: 6),
            ],
          ),
        ),
      );
    });
  }
}
