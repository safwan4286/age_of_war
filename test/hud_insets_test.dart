import 'package:epoch_clash/features/battle/widgets/hud_insets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(800, 360);
  // A camera hole on the right edge, in the middle of the height.
  const hole = Rect.fromLTWH(770, 130, 30, 100);
  const safe = EdgeInsets.symmetric(horizontal: 40);

  test('strips the cutout does not reach hug both edges', () {
    final top = HudInsets.forStrip(screen: screen, cutouts: [hole], safe: safe, top: 0, bottom: 110);
    final low = HudInsets.forStrip(screen: screen, cutouts: [hole], safe: safe, top: 260, bottom: 360);
    expect(top.left, HudInsets.margin);
    expect(top.right, HudInsets.margin);
    expect(low.right, HudInsets.margin);
  });

  test('a strip the cutout reaches steps around it, on its side only', () {
    final mid = HudInsets.forStrip(screen: screen, cutouts: [hole], safe: safe, top: 100, bottom: 200);
    expect(mid.right, greaterThan(30));
    expect(mid.left, HudInsets.margin);
  });

  test('without cutout info it keeps the safe insets', () {
    final s = HudInsets.forStrip(
      screen: screen,
      cutouts: const [],
      safe: safe,
      top: 0,
      bottom: 110,
      cutoutsKnown: false,
    );
    expect(s.left, 40);
    expect(s.right, 40);
  });
}
