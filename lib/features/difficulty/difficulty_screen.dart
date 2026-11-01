import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/game_data.dart';
import '../../resources/assets.dart';
import '../../resources/theme.dart';
import '../../widgets/pixel_box.dart';
import '../../widgets/scenic_backdrop.dart';
import 'difficulty_controller.dart';

class DifficultyScreen extends GetView<DifficultyController> {
  const DifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScenicBackdrop(
        scrim: 0.6,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    PixelButton(
                      label: '<',
                      onTap: Get.back,
                      width: 56,
                      color: Pal.panelHi,
                      textColor: Pal.cream,
                    ),
                    const SizedBox(width: 16),
                    Text('CHOOSE YOUR FOE', style: AppTheme.display(26)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        for (final d in Difficulty.values) ...[
                          _DifficultyCard(d: d),
                          if (d != Difficulty.values.last) const SizedBox(width: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
    final accent = switch (d) {
      Difficulty.easy => Pal.leaf,
      Difficulty.normal => Pal.amber,
      Difficulty.hard => Pal.ember,
    };
    return Semantics(
      button: open,
      label: open ? '${d.label}, best ${c.stars(d)} of 3 stars' : '${d.label}, locked. ${c.lockHint(d)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open ? () => c.start(d) : null,
        child: Opacity(
          opacity: open ? 1 : 0.55,
          child: SizedBox(
            width: 220,
            child: PixelPanel(
              border: open ? accent : Pal.ink,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.label.toUpperCase(), style: AppTheme.display(26, color: accent)),
                  const SizedBox(height: 10),
                  PixelImage(
                    UiImg.unitIcon(switch (d) {
                      Difficulty.easy => 'clubman',
                      Difficulty.normal => 'slinger',
                      Difficulty.hard => 'dinorider',
                    }),
                    size: 72,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: Text(
                      DifficultyController.blurbs[d]!,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(16, color: Pal.muted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (open)
                    StarRow(stars: c.stars(d))
                  else
                    Text(c.lockHint(d).toUpperCase(), textAlign: TextAlign.center, style: AppTheme.display(12)),
                  const SizedBox(height: 12),
                  PixelButton(
                    label: open ? 'FIGHT' : 'LOCKED',
                    onTap: open ? () => c.start(d) : null,
                    color: accent,
                    height: 52,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
