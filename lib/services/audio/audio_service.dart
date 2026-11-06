import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../save_service.dart';
import 'sound_cues.dart';

/// Sound effects and music. Effects are preloaded; each one has a minimum
/// gap so a volley or a big melee doesn't stack into noise. Music loops
/// one track at a time and pauses with the app (FlameAudio.bgm). Both
/// follow the Sound / Music switches in Settings.
class AudioService extends GetxService {
  static AudioService get to => Get.find<AudioService>();

  SaveService get _save => SaveService.to;

  final Map<Sfx, DateTime> _last = {};
  String? _track;
  String? _playing;

  Future<AudioService> init() async {
    await FlameAudio.bgm.initialize();
    try {
      await FlameAudio.audioCache.loadAll([for (final s in Sfx.values) s.file]);
    } catch (e) {
      debugPrint('Audio: preload failed ($e); effects load on first use');
    }
    ever(_save.music, (_) => _applyMusic());
    return this;
  }

  /// Plays an effect unless sound is off or it played a moment ago.
  void play(Sfx sfx, [double volume = 1]) {
    if (!_save.sound.value) return;
    final now = DateTime.now();
    final last = _last[sfx];
    if (last != null && now.difference(last).inMicroseconds < sfx.minGap * 1e6) return;
    _last[sfx] = now;
    unawaited(
      FlameAudio.play(sfx.file, volume: (sfx.volume * volume).clamp(0.0, 1.0)).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('Audio: ${sfx.file} failed ($e)'),
      ),
    );
  }

  void playCues(Iterable<SoundCue> cues) {
    for (final c in cues) {
      play(c.sfx, c.volume);
    }
  }

  /// Switches the looping track (null = silence). Same track keeps playing.
  void music(String? track) {
    _track = track;
    _applyMusic();
  }

  Future<void> _applyMusic() async {
    final want = _save.music.value ? _track : null;
    if (want == _playing) return;
    _playing = want;
    try {
      if (want == null) {
        await FlameAudio.bgm.stop();
      } else {
        await FlameAudio.bgm.play('music/$want.mp3', volume: 0.45);
      }
    } catch (e) {
      // No file for this track yet: stay silent.
      debugPrint('Audio: music $want unavailable ($e)');
      _playing = null;
    }
  }

  /// A one-off jingle (victory/defeat) over silence, then [after] loops.
  Future<void> sting(Sfx sfx, {String? after}) async {
    await FlameAudio.bgm.stop();
    _playing = null;
    play(sfx);
    _track = after;
    Future<void>.delayed(const Duration(seconds: 3), _applyMusic);
  }
}
