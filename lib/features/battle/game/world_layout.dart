/// World-space layout shared by every battle component. The world is 540
/// units tall; the camera zooms so that height fills the screen.
///
/// The two lines match the art bible: the horizon (back edge of the
/// plain) at 62% of the height, the walk line (units' feet) at 77%.
class Layout {
  Layout._();

  static const double worldH = 540;

  /// What the camera shows vertically: more than the 540-tall art
  /// (zoomed out ~28%, units about Age of War size). The sky and ground
  /// layers extend to cover it.
  static const double viewH = 690;
  static const double viewTop = -110;

  /// Back edge of the ground plain, where the jungle meets the sand.
  static const double horizonY = 335;

  /// Where units' feet touch the ground.
  static const double groundY = 418;

  /// The base picture's foot sits this far below the walk line. Kept
  /// tiny: units spawn in the gateway, and a deeper base made them look
  /// like they stood in the air in front of it.
  static const double baseSink = 1;

  /// How much of our base the battle opens on, behind the gate. A big
  /// castle is otherwise half the screen; dragging still shows all of it.
  static const double baseShow = 300;

  /// Turret width on a ledge; height follows the art.
  static const double turretW = 76;

  /// Background layers repeat sideways (every other copy mirrored, so any
  /// picture joins without a seam), drawn 540 tall at their own aspect.
  /// This is where the first copy starts.
  static const double bgLeft = -160;

  /// The camera rests showing the whole base plus this much behind it.
  static const double camMargin = 30;

  /// How far a drag can pull past either end before it springs back.
  static const double overscroll = 110;

  /// Where slingers release and where shots land.
  static const double slingY = groundY - 52;
  static const double hitY = groundY - 40;
}
