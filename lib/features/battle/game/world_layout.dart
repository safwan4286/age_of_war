/// World-space layout shared by every battle component. The world is 540
/// units tall; the camera zooms so that height fills the screen.
///
/// The two lines match the art bible: the horizon (back edge of the
/// plain) at 62% of the height, the walk line (units' feet) at 77%.
class Layout {
  Layout._();

  static const double worldH = 540;

  /// Back edge of the ground plain, where the jungle meets the sand.
  static const double horizonY = 335;

  /// Where units' feet touch the ground.
  static const double groundY = 418;

  /// The base picture's foot sits this far below the walk line.
  static const double baseSink = 10;

  /// Turret width on a ledge; height follows the art.
  static const double turretW = 76;

  /// Background layers: 32:9 art drawn at 1920x540, starting a bit
  /// before the player's base so the edges never show.
  static const double bgW = 1920;
  static const double bgLeft = -160;

  /// The camera may look this far past either base.
  static const double camMargin = 40;

  /// Where slingers release and where shots land.
  static const double slingY = groundY - 52;
  static const double hitY = groundY - 40;
}
