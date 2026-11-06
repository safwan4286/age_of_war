import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'resources/routes.dart';
import 'resources/theme.dart';
import 'services/audio/audio_service.dart';
import 'services/game_data_service.dart';
import 'services/responsiveness/device_manager.dart';
import 'services/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.setLandscape();
  await Flame.device.fullScreen();
  _registerLicences();

  await Hive.initFlutter();
  await Get.putAsync<SaveService>(() => SaveService().init(), permanent: true);
  await Get.putAsync<GameDataService>(
    () => GameDataService().init(),
    permanent: true,
  );
  await Get.putAsync<AudioService>(() => AudioService().init(), permanent: true);

  runApp(const EpochClashApp());
}

class EpochClashApp extends StatelessWidget {
  const EpochClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Epoch Clash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: Routes.menu,
      getPages: Routes.pages,
      defaultTransition: Transition.fadeIn,
      // UI sizes scale with the screen (DeviceManager, `.sp`); system text
      // scaling is capped so the HUD never overflows.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final data = mq.copyWith(
          textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15),
        );
        DeviceManager.instance.initWith(data);
        return MediaQuery(data: data, child: child ?? const SizedBox.shrink());
      },
    );
  }
}

void _registerLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [
      ('Lilita One', 'assets/fonts/OFL-LilitaOne.txt'),
      ('Nunito', 'assets/fonts/OFL-Nunito.txt'),
    ]) {
      final text = await rootBundle.loadString(file);
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
}
