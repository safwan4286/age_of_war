import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/game_data.dart';
import '../resources/assets.dart';

/// Loads the balance file once at startup.
class GameDataService extends GetxService {
  late final GameData data;

  static GameDataService get to => Get.find<GameDataService>();

  Future<GameDataService> init() async {
    final raw = await rootBundle.loadString(AppAssets.unitsJson);
    data = GameData.fromMap(jsonDecode(raw) as Map);
    return this;
  }
}
