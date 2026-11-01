import 'package:get/get.dart';

import '../features/battle/battle_binding.dart';
import '../features/battle/battle_screen.dart';
import '../features/difficulty/difficulty_binding.dart';
import '../features/difficulty/difficulty_screen.dart';
import '../features/menu/menu_binding.dart';
import '../features/menu/menu_screen.dart';
import '../features/results/results_binding.dart';
import '../features/results/results_screen.dart';
import '../features/settings/settings_binding.dart';
import '../features/settings/settings_screen.dart';

class Routes {
  Routes._();

  static const menu = '/menu';
  static const difficulty = '/difficulty';
  static const battle = '/battle';
  static const results = '/results';
  static const settings = '/settings';

  static final pages = <GetPage<dynamic>>[
    GetPage(name: menu, page: () => const MenuScreen(), binding: MenuBinding()),
    GetPage(
      name: difficulty,
      page: () => const DifficultyScreen(),
      binding: DifficultyBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: battle,
      page: () => const BattleScreen(),
      binding: BattleBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: results,
      page: () => const ResultsScreen(),
      binding: ResultsBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: settings,
      page: () => const SettingsScreen(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
