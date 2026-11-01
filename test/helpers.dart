import 'dart:convert';
import 'dart:io';

import 'package:epoch_clash/models/game_data.dart';
import 'package:epoch_clash/services/sim/battle_sim.dart';

/// The real balance file, so tests break when tuning breaks a rule.
GameData loadData() {
  final raw = File('assets/data/units.json').readAsStringSync();
  return GameData.fromMap(jsonDecode(raw) as Map);
}

/// Steps [sim] in 1/20 s ticks for [seconds], or until it ends.
void run(BattleSim sim, double seconds, {void Function()? each}) {
  final ticks = (seconds * 20).round();
  for (var i = 0; i < ticks && sim.outcome == null; i++) {
    each?.call();
    sim.step(0.05);
  }
}

/// Puts a unit straight onto the lane, skipping gold and training.
SimUnit place(BattleSim sim, Side side, String id, double x) {
  final st = sim[side];
  st.gold += sim.data.unit(id).cost;
  sim.queueUnit(side, id);
  st.trainLeft = 0;
  // Spawn happens on the next step; move it after.
  sim.step(0.0001);
  final u = sim.units.last;
  u.x = x;
  return u;
}
