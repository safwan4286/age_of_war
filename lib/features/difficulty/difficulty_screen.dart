import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/game_data.dart';
import '../../resources/assets.dart';
import '../../resources/theme.dart';
import '../../services/responsiveness/device_manager.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/scenic_backdrop.dart';
import 'difficulty_controller.dart';

class DifficultyScreen extends GetView<DifficultyController> {
  const DifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScenicBackdrop(
        scrim: 0.5,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.sp, 10.sp, 14.sp, 10.sp),
            child: Column(
              children: [
                Row(
                  children: [
                    GameSquareButton(label: '<', semantics: 'Back', onTap: Get.back),
                    SizedBox(width: 14.sp),
                    Text('CHOOSE YOUR FOE', style: AppTheme.display(32)),
                  ],
                ),
                SizedBox(height: 10.sp),
                // The three cards share the width; if the phone is short,
                // the whole row scales down instead of overflowing.
                Expanded(
                  child: FitScreen(
                    maxWidth: 780,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final d in Difficulty.values) ...[
                          Expanded(child: _DifficultyCard(d: d)),
                          if (d != Difficulty.values.last) SizedBox(width: 14.sp),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyCard extends GetView<DifficultyController> {
  const _DifficultyCard({required this.d});

  final Difficulty d;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final open = c.unlocked(d);
    final (accent, tone) = switch (d) {
      Difficulty.easy => (Pal.leaf, GameTone.leaf),
      Difficulty.normal => (Pal.amber, GameTone.gold),
      Difficulty.hard => (Pal.ember, GameTone.ember),
    };
    return Semantics(
      button: open,
      label: open ? '${d.label}, best ${c.stars(d)} of 3 stars' : '${d.label}, locked. ${c.lockHint(d)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open ? () => c.start(d) : null,
        child: Opacity(
          opacity: open ? 1 : 0.6,
          child: GamePanel(
            accent: open ? accent : null,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(d.label.toUpperCase(), style: AppTheme.display(32, color: accent)),
                SizedBox(height: 8.sp),
                // The foe's champion, full body in enemy red, standing in a
                // little sky-and-sand window.
                Container(
                  height: 132.sp,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.sp),
                    border: Border.all(color: Pal.ink, width: 3.sp),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.72, 0.72, 1],
                      colors: [Color(0xFF8FB8D8), Color(0xFFE9C9A0), Color(0xFFD8B47A), Color(0xFFC79D60)],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11.sp),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(6.sp, 8.sp, 6.sp, 6.sp),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          UiImg.unitPose(switch (d) {
                            Difficulty.easy => 'clubman',
                            Difficulty.normal => 'slinger',
                            Difficulty.hard => 'dinorider',
                          }, red: true),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.sp),
                SizedBox(
                  height: 52.sp,
                  child: Center(
                    child: Text(
                      DifficultyController.blurbs[d]!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTheme.body(16, color: Pal.cream),
                    ),
                  ),
                ),
                SizedBox(height: 6.sp),
                SizedBox(
                  height: 40.sp,
                  child: Center(
                    child: open
                        ? StarRow(stars: c.stars(d), size: 32)
                        : Text(
                            c.lockHint(d).toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppTheme.display(14, color: Pal.muted),
                          ),
                  ),
                ),
                SizedBox(height: 10.sp),
                GameButton(
                  label: open ? 'FIGHT' : 'LOCKED',
                  icon: open ? null : UiImg.lock,
                  onTap: open ? () => c.start(d) : null,
                  tone: tone,
                  height: 56,
                  fontSize: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
