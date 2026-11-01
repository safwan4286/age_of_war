import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../widgets/pixel_box.dart';
import '../battle_controller.dart';

/// Top corners: your base, specials, gold, population and XP on the left;
/// the enemy base, speed and pause on the right. The middle stays clear.
class HudTop extends GetView<BattleController> {
  const HudTop({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return LayoutBuilder(
      builder: (context, box) {
        final barW = box.maxWidth < 760 ? 150.0 : 210.0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
                    () => _BaseHp(
                      title: 'YOUR CAVE',
                      value: c.playerHp.value,
                      color: Pal.leaf,
                      width: barW,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(
                        () => HudIconButton(
                          icon: UiImg.meteor,
                          label: c.meteorReady ? 'READY' : '${(c.meteorFraction.value * 100).floor()}%',
                          semantics: c.meteorReady ? 'Meteor strike ready' : 'Meteor strike charging',
                          enabled: c.meteorReady,
                          fill: c.meteorFraction.value,
                          onTap: c.castMeteor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Obx(
                        () => HudIconButton(
                          icon: UiImg.evolve,
                          label: c.canEvolve ? 'EVOLVE' : 'AGE',
                          semantics: c.canEvolve ? 'Evolve to the next age' : 'Evolve needs ${c.evolveXp} XP',
                          enabled: c.canEvolve,
                          fill: (c.xp.value / c.evolveXp).clamp(0.0, 1.0),
                          onTap: c.tapEvolve,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _Wallet(),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Obx(
                    () => _BaseHp(
                      title: 'ENEMY CAVE',
                      value: c.enemyHp.value,
                      color: Pal.ember,
                      width: barW,
                      reverse: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => _SquareButton(
                          label: '${c.speed.value}X',
                          semantics: 'Battle speed ${c.speed.value} times',
                          onTap: c.toggleSpeed,
                          highlight: c.speed.value > 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SquareButton(label: 'II', semantics: 'Pause', onTap: c.pause),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BaseHp extends StatelessWidget {
  const _BaseHp({
    required this.title,
    required this.value,
    required this.color,
    required this.width,
    this.reverse = false,
  });

  final String title;
  final double value;
  final Color color;
  final double width;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).ceil().clamp(0, 100);
    return PixelBar(
      value: value,
      color: color,
      label: '$title  $pct%',
      width: width,
      height: 20,
      reverse: reverse,
    );
  }
}

/// Gold, population and XP, stacked.
class _Wallet extends GetView<BattleController> {
  const _Wallet();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Chip(
            icon: UiImg.gold,
            text: '${c.gold.value}',
            color: Pal.amber,
            semantics: '${c.gold.value} gold',
          ),
          const SizedBox(height: 4),
          _Chip(
            icon: UiImg.unitIcon('clubman'),
            text: '${c.population.value}/${c.popCap}',
            color: c.popFull ? Pal.ember : Pal.cream,
            semantics: '${c.population.value} of ${c.popCap} units',
          ),
          const SizedBox(height: 4),
          PixelBar(
            value: c.xp.value / c.evolveXp,
            color: Pal.xp,
            label: c.canEvolve ? 'EVOLVE!' : '${c.xp.value} XP',
            width: 96,
            height: 14,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.color,
    required this.semantics,
  });

  final String icon;
  final String text;
  final Color color;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xB30F1720),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            PixelImage(icon, size: 16),
            const SizedBox(width: 6),
            Text(text, style: AppTheme.display(14, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Round-cornered icon button with a charge fill (meteor, evolve, turret).
class HudIconButton extends StatelessWidget {
  const HudIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semantics,
    required this.enabled,
    required this.onTap,
    this.fill,
    this.size = 56,
  });

  final String icon;
  final String label;
  final String semantics;
  final bool enabled;
  final VoidCallback onTap;
  final double? fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      enabled: enabled,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size + 8,
          decoration: BoxDecoration(
            color: const Color(0xCC24364A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? Pal.amber : Pal.ink, width: 3),
            boxShadow: enabled
                ? const [BoxShadow(color: Color(0x88F2B33D), blurRadius: 10, spreadRadius: 1)]
                : null,
          ),
          child: Stack(
            children: [
              if (fill != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: fill!.clamp(0.0, 1.0),
                    widthFactor: 1,
                    child: const ColoredBox(color: Color(0x553F2A5C)),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelImage(icon, size: size * 0.58, opacity: enabled ? 1 : 0.55),
                    const SizedBox(height: 2),
                    Text(label, style: AppTheme.display(10, color: enabled ? Pal.cream : Pal.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.label,
    required this.semantics,
    required this.onTap,
    this.highlight = false,
  });

  final String label;
  final String semantics;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: PixelButton(
        label: label,
        onTap: onTap,
        width: 52,
        height: 48,
        fontSize: 16,
        color: highlight ? Pal.amber : Pal.panelHi,
        textColor: highlight ? Pal.ink : Pal.cream,
      ),
    );
  }
}
