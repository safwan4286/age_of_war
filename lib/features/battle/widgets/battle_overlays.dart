import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../widgets/pixel_box.dart';
import '../battle_controller.dart';

/// Whichever modal the battle is showing (the battle is frozen meanwhile).
/// Place it inside a `Positioned.fill`; when nothing is open it is empty
/// and lets touches through.
class BattleOverlays extends GetView<BattleController> {
  const BattleOverlays({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final o = controller.overlay.value;
      if (o == BattleOverlay.none) return const SizedBox.shrink();
      return ColoredBox(
          color: const Color(0xB30F1720),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: switch (o) {
                BattleOverlay.tutorial => const _Tutorial(),
                BattleOverlay.paused => const _Paused(),
                BattleOverlay.evolveTeaser => const _EvolveTeaser(),
                BattleOverlay.turrets => const _Turrets(),
                BattleOverlay.none => const SizedBox.shrink(),
              },
            ),
          ),
      );
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: PixelPanel(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, textAlign: TextAlign.center, style: AppTheme.display(24, color: Pal.amber)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Tutorial extends GetView<BattleController> {
  const _Tutorial();

  static const _steps = [
    (
      UiImg.gold,
      'TRAIN YOUR TRIBE',
      'Tap a unit card to train it. Units walk toward the enemy cave and fight on their own.',
    ),
    (
      UiImg.xp,
      'EARN GOLD & XP',
      'Every kill pays more gold than the unit cost, plus XP. Fill the XP bar to unlock the next age.',
    ),
    (
      UiImg.meteor,
      'DEFEND & STRIKE',
      'Buy a Rock Thrower for your cave, and call the Meteor when it is charged. Drag the battlefield to look around. Destroy the enemy cave to win!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      final i = c.tutorialStep.value;
      final (icon, title, body) = _steps[i];
      final last = i == _steps.length - 1;
      return _Card(
        title: title,
        children: [
          PixelImage(icon, size: 56),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center, style: AppTheme.body(18)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var d = 0; d < _steps.length; d++)
                Container(
                  width: d == i ? 22 : 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: d == i ? Pal.amber : Pal.panelHi,
                ),
            ],
          ),
          const SizedBox(height: 16),
          PixelButton(label: last ? 'TO BATTLE!' : 'NEXT', onTap: c.nextTutorialStep),
        ],
      );
    });
  }
}

class _Paused extends GetView<BattleController> {
  const _Paused();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _Card(
      title: 'PAUSED',
      children: [
        PixelButton(label: 'RESUME', onTap: c.resume),
        const SizedBox(height: 12),
        PixelButton(label: 'RESTART', onTap: c.restart, color: Pal.panelHi, textColor: Pal.cream),
        const SizedBox(height: 12),
        PixelButton(label: 'QUIT TO MENU', onTap: c.quit, color: Pal.ember, textColor: Pal.cream),
      ],
    );
  }
}

class _EvolveTeaser extends GetView<BattleController> {
  const _EvolveTeaser();

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'MEDIEVAL AGE',
      children: [
        const PixelImage(UiImg.evolve, size: 64),
        const SizedBox(height: 12),
        Text(
          'Your tribe is ready to evolve! Knights, archers and stone castles arrive in the next update.',
          textAlign: TextAlign.center,
          style: AppTheme.body(18),
        ),
        const SizedBox(height: 6),
        Text('COMING SOON', textAlign: TextAlign.center, style: AppTheme.display(16, color: Pal.xp)),
        const SizedBox(height: 16),
        PixelButton(label: 'KEEP FIGHTING', onTap: controller.closeOverlay),
      ],
    );
  }
}

class _Turrets extends GetView<BattleController> {
  const _Turrets();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = c.data.turret;
    return Obx(
      () => _Card(
        title: 'TURRETS',
        children: [
          Text(
            '${t.name}: ${t.damage.round()} damage, reaches ${t.range.round()} from your cave. '
            'Build one on each ledge.',
            textAlign: TextAlign.center,
            style: AppTheme.body(16, color: Pal.muted),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < c.turrets.length; i++) ...[
            Row(
              children: [
                const PixelImage(UiImg.turret, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'LEDGE ${i + 1}${c.turrets[i] ? '  ·  BUILT' : ''}',
                    style: AppTheme.display(15, color: c.turrets[i] ? Pal.leaf : Pal.cream),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: c.turrets[i]
                      ? PixelButton(
                          label: 'SELL +${t.sellBack}',
                          onTap: () => c.sellTurret(i),
                          color: Pal.panelHi,
                          textColor: Pal.cream,
                          height: 48,
                          fontSize: 14,
                        )
                      : PixelButton(
                          label: 'BUILD ${t.cost}',
                          onTap: c.gold.value >= t.cost ? () => c.buildTurret(i) : null,
                          height: 48,
                          fontSize: 14,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          PixelButton(label: 'BACK TO BATTLE', onTap: c.closeOverlay, color: Pal.panelHi, textColor: Pal.cream),
        ],
      ),
    );
  }
}
