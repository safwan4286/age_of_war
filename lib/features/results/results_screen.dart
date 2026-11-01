import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/assets.dart';
import '../../resources/theme.dart';
import '../../widgets/pixel_box.dart';
import '../../widgets/scenic_backdrop.dart';
import 'results_controller.dart';

class ResultsScreen extends GetView<ResultsController> {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = c.result;
    final next = c.next;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.menu();
      },
      child: Scaffold(
        body: ScenicBackdrop(
          scrim: 0.65,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: PixelPanel(
                    border: r.victory ? Pal.amber : Pal.ember,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.victory ? 'VICTORY!' : 'DEFEAT',
                          style: AppTheme.display(44, color: r.victory ? Pal.amber : Pal.ember),
                        ),
                        Text(
                          r.victory
                              ? 'The enemy cave has fallen.'
                              : 'Your cave has fallen. Regroup and try again.',
                          textAlign: TextAlign.center,
                          style: AppTheme.body(18, color: Pal.muted),
                        ),
                        const SizedBox(height: 12),
                        if (r.victory) _Stars(),
                        if (r.newBest) ...[
                          const SizedBox(height: 6),
                          Text('NEW BEST!', style: AppTheme.display(16, color: Pal.leaf)),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _Stat(label: 'TIME', value: r.timeLabel),
                            _Stat(label: 'KILLS', value: '${r.kills}'),
                            _Stat(label: 'GOLD', value: '${r.goldEarned}', icon: UiImg.gold),
                            _Stat(label: 'XP', value: '${r.xp}', icon: UiImg.xp),
                            _Stat(label: 'CAVE', value: '${(r.baseHpLeft * 100).ceil()}%'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: PixelButton(
                                label: 'MENU',
                                onTap: c.menu,
                                color: Pal.panelHi,
                                textColor: Pal.cream,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PixelButton(
                                label: 'RETRY',
                                onTap: c.retry,
                                color: next == null ? Pal.amber : Pal.panelHi,
                                textColor: next == null ? Pal.ink : Pal.cream,
                              ),
                            ),
                            if (next != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: PixelButton(
                                  label: next.label.toUpperCase(),
                                  onTap: c.playNext,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stars extends GetView<ResultsController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shown = controller.shownStars.value;
      return Semantics(
        label: '${controller.result.stars} of 3 stars',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedScale(
                scale: i < shown ? 1 : 0.7,
                duration: const Duration(milliseconds: 260),
                curve: Curves.elasticOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PixelImage(i < shown ? UiImg.star : UiImg.starEmpty, size: 56),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Pal.ink.withValues(alpha: 0.5),
        border: Border.all(color: Pal.panelHi, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: AppTheme.display(11, color: Pal.muted)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[PixelImage(icon!, size: 14), const SizedBox(width: 4)],
              Text(value, style: AppTheme.display(18)),
            ],
          ),
        ],
      ),
    );
  }
}
