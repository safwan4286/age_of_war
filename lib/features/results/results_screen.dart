import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../resources/assets.dart';
import '../../resources/theme.dart';
import '../../services/responsiveness/device_manager.dart';
import '../../widgets/game_ui.dart';
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
          scrim: 0.55,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(12.sp),
              child: FitScreen(
                maxWidth: 580,
                child: GamePanel(
                  accent: r.victory ? Pal.amber : Pal.ember,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.victory ? 'VICTORY!' : 'DEFEAT',
                        style: AppTheme.display(54, color: r.victory ? Pal.amber : Pal.ember),
                      ),
                      Text(
                        r.victory
                            ? 'The enemy cave has fallen.'
                            : 'Your cave has fallen. Regroup and try again.',
                        textAlign: TextAlign.center,
                        style: AppTheme.body(18),
                      ),
                      SizedBox(height: 10.sp),
                      if (r.victory) const _Stars(),
                      if (r.newBest) ...[
                        SizedBox(height: 6.sp),
                        Text('NEW BEST!', style: AppTheme.display(20, color: Pal.leaf)),
                      ],
                      SizedBox(height: 12.sp),
                      Wrap(
                        spacing: 10.sp,
                        runSpacing: 10.sp,
                        alignment: WrapAlignment.center,
                        children: [
                          _Stat(label: 'TIME', value: r.timeLabel),
                          _Stat(label: 'KILLS', value: '${r.kills}'),
                          _Stat(label: 'GOLD', value: '${r.goldEarned}', icon: UiImg.gold),
                          _Stat(label: 'XP', value: '${r.xp}', icon: UiImg.xp),
                          _Stat(label: 'CAVE', value: '${(r.baseHpLeft * 100).ceil()}%'),
                        ],
                      ),
                      SizedBox(height: 18.sp),
                      Row(
                        children: [
                          Expanded(
                            child: GameButton(label: 'MENU', onTap: c.menu, tone: GameTone.stone),
                          ),
                          SizedBox(width: 12.sp),
                          Expanded(
                            child: GameButton(
                              label: 'RETRY',
                              onTap: c.retry,
                              tone: next == null ? GameTone.gold : GameTone.stone,
                            ),
                          ),
                          if (next != null) ...[
                            SizedBox(width: 12.sp),
                            Expanded(
                              child: GameButton(label: next.label.toUpperCase(), onTap: c.playNext),
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
    );
  }
}

class _Stars extends GetView<ResultsController> {
  const _Stars();

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
                  padding: EdgeInsets.symmetric(horizontal: 4.sp),
                  child: GameImage(i < shown ? UiImg.star : UiImg.starEmpty, size: 60),
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
      width: 92.sp,
      padding: EdgeInsets.symmetric(vertical: 8.sp),
      decoration: BoxDecoration(
        color: Pal.shade,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: Pal.ink, width: 2.5.sp),
      ),
      child: Column(
        children: [
          Text(label, style: AppTheme.display(14, color: Pal.muted)),
          SizedBox(height: 4.sp),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[GameImage(icon!, size: 18), SizedBox(width: 4.sp)],
              Text(value, style: AppTheme.display(22)),
            ],
          ),
        ],
      ),
    );
  }
}
