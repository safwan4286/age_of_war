import 'package:flutter/material.dart' hide MenuController;
import 'package:get/get.dart';

import '../../resources/assets.dart';
import '../../resources/theme.dart';
import '../../services/responsiveness/device_manager.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/scenic_backdrop.dart';
import 'menu_controller.dart';

class MenuScreen extends GetView<MenuController> {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      body: ScenicBackdrop(
        scrim: 0.25,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12.sp),
            child: FitScreen(
              maxWidth: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Title(),
                  SizedBox(height: 22.sp),
                  GameButton(label: 'PLAY', onTap: c.play, width: 300, height: 72, fontSize: 38),
                  SizedBox(height: 14.sp),
                  GameButton(
                    label: 'SETTINGS',
                    onTap: c.openSettings,
                    tone: GameTone.stone,
                    width: 300,
                    height: 58,
                    fontSize: 26,
                  ),
                  SizedBox(height: 16.sp),
                  Obx(
                    () => Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 6.sp),
                      decoration: BoxDecoration(
                        color: Pal.shade,
                        borderRadius: BorderRadius.circular(20.sp),
                        border: Border.all(color: Pal.ink, width: 2.sp),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GameImage(UiImg.star, size: 24),
                          SizedBox(width: 8.sp),
                          Text('${c.totalStars.value} / 9', style: AppTheme.display(20)),
                        ],
                      ),
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
  const _Title();

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
        offset: Offset(0, -4.sp * Curves.easeInOut.transform(_bob.value)),
        child: child,
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'EPOCH CLASH',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppTheme.display(76, color: Pal.amber).copyWith(
                shadows: [
                  ...AppTheme.outline(76.sp),
                  Shadow(color: Pal.ink, offset: Offset(0, 7.sp)),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.sp),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 3.sp),
            decoration: BoxDecoration(
              color: Pal.ember,
              borderRadius: BorderRadius.circular(8.sp),
              border: Border.all(color: Pal.ink, width: 2.5.sp),
            ),
            child: Text('STONE AGE', style: AppTheme.display(20)),
          ),
        ],
      ),
    );
  }
}
