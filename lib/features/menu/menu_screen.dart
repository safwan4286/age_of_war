import 'package:flutter/material.dart' hide MenuController;
import 'package:get/get.dart';

import '../../resources/assets.dart';
import '../../resources/theme.dart';
import '../../widgets/pixel_box.dart';
import '../../widgets/scenic_backdrop.dart';
import 'menu_controller.dart';

class MenuScreen extends GetView<MenuController> {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      body: ScenicBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Title(),
                  const SizedBox(height: 28),
                  PixelButton(label: 'PLAY', onTap: c.play, width: 260, height: 64, fontSize: 26),
                  const SizedBox(height: 14),
                  PixelButton(
                    label: 'SETTINGS',
                    onTap: c.openSettings,
                    width: 260,
                    color: Pal.panelHi,
                    textColor: Pal.cream,
                  ),
                  const SizedBox(height: 18),
                  Obx(
                    () => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PixelImage(UiImg.star, size: 22),
                        const SizedBox(width: 6),
                        Text('${c.totalStars.value} / 9', style: AppTheme.display(16)),
                      ],
                    ),
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

class _Title extends StatefulWidget {
  @override
  State<_Title> createState() => _TitleState();
}

class _TitleState extends State<_Title> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 * Curves.easeInOut.transform(_bob.value)),
        child: child,
      ),
      child: Column(
        children: [
          Text(
            'EPOCH CLASH',
            textAlign: TextAlign.center,
            style: AppTheme.display(54, color: Pal.amber).copyWith(
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Pal.ink, offset: Offset(0, 4)),
                Shadow(color: Pal.ember, offset: Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('— STONE AGE —', style: AppTheme.display(18)),
        ],
      ),
    );
  }
}
