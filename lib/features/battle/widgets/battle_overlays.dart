import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/game_data.dart';
import '../../../resources/assets.dart';
import '../../../resources/theme.dart';
import '../../../services/responsiveness/device_manager.dart';
import '../../../widgets/game_ui.dart';
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
        color: Pal.ink.withValues(alpha: 0.6),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12.sp),
            child: FitScreen(
              maxWidth: o == BattleOverlay.upgrades ? 720 : 480,
              child: switch (o) {
                BattleOverlay.tutorial => const _Tutorial(),
                BattleOverlay.paused => const _Paused(),
                BattleOverlay.evolveTeaser => const _EvolveTeaser(),
                BattleOverlay.turrets => const _Turrets(),
                BattleOverlay.upgrades => const _Upgrades(),
                BattleOverlay.none => const SizedBox.shrink(),
              },
            ),
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
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.center, style: AppTheme.display(32, color: Pal.amber)),
          SizedBox(height: 12.sp),
          ...children,
        ],
      ),
    );
  }
}

class _Tutorial extends GetView<BattleController> {
  const _Tutorial();

  static final _steps = [
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
      UiImg.icon('icon_meteor'),
      'DEFEND & STRIKE',
      'Build Rock Throwers on your cave, buy upgrades with spare gold, and call the Meteor when it is charged. Drag the battlefield to look around. Destroy the enemy cave to win!',
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
          Center(child: GameImage(icon, size: 60)),
          SizedBox(height: 10.sp),
          Text(body, textAlign: TextAlign.center, style: AppTheme.body(18)),
          SizedBox(height: 14.sp),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var d = 0; d < _steps.length; d++)
                Container(
                  width: (d == i ? 24 : 12).sp,
                  height: 12.sp,
                  margin: EdgeInsets.symmetric(horizontal: 3.sp),
                  decoration: BoxDecoration(
                    color: d == i ? Pal.amber : Pal.stoneTop,
                    borderRadius: BorderRadius.circular(6.sp),
                    border: Border.all(color: Pal.ink, width: 2.sp),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.sp),
          GameButton(label: last ? 'TO BATTLE!' : 'NEXT', onTap: c.nextTutorialStep),
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
        GameButton(label: 'RESUME', onTap: c.resume),
        SizedBox(height: 12.sp),
        GameButton(label: 'RESTART', onTap: c.restart, tone: GameTone.stone),
        SizedBox(height: 12.sp),
        GameButton(label: 'QUIT TO MENU', onTap: c.quit, tone: GameTone.ember),
      ],
    );
  }
}

class _EvolveTeaser extends GetView<BattleController> {
  const _EvolveTeaser();

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'NEW AGES SOON',
      children: [
        Center(child: GameImage(UiImg.evolve(controller.playerEra), size: 68)),
        SizedBox(height: 10.sp),
        Text(
          'You reached the last age for now. Gunpowder and beyond arrive in a later update.',
          textAlign: TextAlign.center,
          style: AppTheme.body(18),
        ),
        SizedBox(height: 6.sp),
        Text('COMING SOON', textAlign: TextAlign.center, style: AppTheme.display(20, color: Pal.xp)),
        SizedBox(height: 14.sp),
        GameButton(label: 'KEEP FIGHTING', onTap: controller.closeOverlay),
      ],
    );
  }
}

class _Turrets extends GetView<BattleController> {
  const _Turrets();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      final t = c.playerEra.turret;
      return _Card(
        title: 'TURRETS',
        children: [
          Text(
            '${t.name}: ${t.damage.round()} damage, reaches ${t.range.round()} from your cave. '
            'Build one on each spot.',
            textAlign: TextAlign.center,
            style: AppTheme.body(16, color: Pal.muted),
          ),
          SizedBox(height: 12.sp),
          for (var i = 0; i < c.turrets.length; i++) ...[
            Row(
              children: [
                GameImage(UiImg.turret(c.playerEra), size: 40),
                SizedBox(width: 10.sp),
                Expanded(
                  child: Text(
                    'SPOT ${i + 1}${c.turrets[i] ? '  ·  BUILT' : ''}',
                    style: AppTheme.display(18, color: c.turrets[i] ? Pal.leaf : Pal.cream),
                  ),
                ),
                SizedBox(
                  width: 160.sp,
                  child: c.turrets[i]
                      ? GameButton(
                          label: 'SELL +${t.sellBack}',
                          onTap: () => c.sellTurret(i),
                          tone: GameTone.stone,
                          height: 50,
                          fontSize: 18,
                        )
                      : GameButton(
                          label: 'BUILD ${t.cost}',
                          icon: UiImg.gold,
                          onTap: c.gold.value >= t.cost ? () => c.buildTurret(i) : null,
                          height: 50,
                          fontSize: 18,
                        ),
                ),
              ],
            ),
            SizedBox(height: 10.sp),
          ],
          SizedBox(height: 4.sp),
          GameButton(label: 'BACK TO BATTLE', onTap: c.closeOverlay, tone: GameTone.stone),
        ],
      );
    });
  }
}

class _Upgrades extends GetView<BattleController> {
  const _Upgrades();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final list = c.data.upgrades;
    return Obx(() {
      // Touch the Rx values so the menu refreshes after a purchase.
      c.upgrades.length;
      c.gold.value;
      return _Card(
        title: 'UPGRADES',
        children: [
          Text(
            'Upgrades last for this battle.',
            textAlign: TextAlign.center,
            style: AppTheme.body(15, color: Pal.muted),
          ),
          SizedBox(height: 10.sp),
          for (var i = 0; i < list.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _UpgradeTile(u: list[i])),
                SizedBox(width: 10.sp),
                Expanded(child: i + 1 < list.length ? _UpgradeTile(u: list[i + 1]) : const SizedBox.shrink()),
              ],
            ),
            SizedBox(height: 10.sp),
          ],
          GameButton(label: 'BACK TO BATTLE', onTap: c.closeOverlay, tone: GameTone.stone),
        ],
      );
    });
  }
}

class _UpgradeTile extends GetView<BattleController> {
  const _UpgradeTile({required this.u});

  final UpgradeDef u;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final lvl = c.upgradeLevel(u.id);
    final cost = c.upgradeCost(u.id);
    final pct = (u.per * 100).round();
    final sign = u.stat == UpgradeStat.armor ? '-' : '+';
    final what = switch (u.stat) {
      UpgradeStat.damage => 'damage',
      UpgradeStat.armor => 'damage taken',
      UpgradeStat.range => 'range',
    };
    final now = lvl == 0 ? 'No bonus yet' : 'Now $sign${pct * lvl}% $what';
    final portrait = switch (u.target) {
      UpgradeTarget.melee => UiImg.unitCard(c.playerEra.byRole(UnitRole.melee)?.sprite ?? 'clubman'),
      UpgradeTarget.ranged => UiImg.unitCard(c.playerEra.byRole(UnitRole.ranged)?.sprite ?? 'slinger'),
      UpgradeTarget.turret => UiImg.turret(c.playerEra),
    };
    final badge = switch (u.stat) {
      UpgradeStat.damage => Icons.bolt_rounded,
      UpgradeStat.armor => Icons.shield_rounded,
      UpgradeStat.range => Icons.open_in_full_rounded,
    };
    return Container(
      padding: EdgeInsets.all(8.sp),
      decoration: BoxDecoration(
        color: Pal.shade,
        borderRadius: BorderRadius.circular(14.sp),
        border: Border.all(color: Pal.ink, width: 2.5.sp),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54.sp,
            height: 54.sp,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.sp),
                    border: Border.all(color: Pal.ink, width: 2.sp),
                    color: const Color(0xFF5C86A8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.sp),
                    child: GameImage(portrait, size: 54, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: -6.sp,
                  bottom: -6.sp,
                  child: Container(
                    width: 24.sp,
                    height: 24.sp,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Pal.amber,
                      border: Border.all(color: Pal.ink, width: 2.sp),
                    ),
                    child: Icon(badge, size: 15.sp, color: Pal.ink),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name.toUpperCase(), style: AppTheme.display(17)),
                SizedBox(height: 2.sp),
                Text(u.desc, maxLines: 2, style: AppTheme.body(12, color: Pal.muted)),
                SizedBox(height: 4.sp),
                Row(
                  children: [
                    for (var k = 0; k < u.maxLevel; k++)
                      Container(
                        width: 14.sp,
                        height: 8.sp,
                        margin: EdgeInsets.only(right: 3.sp),
                        decoration: BoxDecoration(
                          color: k < lvl ? Pal.leaf : const Color(0xFF1E140C),
                          borderRadius: BorderRadius.circular(3.sp),
                          border: Border.all(color: Pal.ink, width: 1.5.sp),
                        ),
                      ),
                    SizedBox(width: 6.sp),
                    Flexible(
                      child: Text(
                        now,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(11, color: lvl > 0 ? Pal.leaf : Pal.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.sp),
          SizedBox(
            width: 96.sp,
            child: cost == null
                ? GameButton(
                    label: 'MAX',
                    semanticsLabel: '${u.name} fully upgraded',
                    onTap: null,
                    height: 46,
                    fontSize: 18,
                  )
                : GameButton(
                    label: '$cost',
                    semanticsLabel: 'Buy ${u.name} level ${lvl + 1} for $cost gold',
                    icon: UiImg.gold,
                    onTap: c.gold.value >= cost ? () => c.buyUpgrade(u.id) : null,
                    tone: GameTone.leaf,
                    height: 46,
                    fontSize: 18,
                  ),
          ),
        ],
      ),
    );
  }
}
