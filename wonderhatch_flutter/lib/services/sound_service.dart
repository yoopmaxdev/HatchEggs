import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  AudioPlayer? _player;
  bool muted = false;

  Future<void> playPop() async {
    HapticFeedback.mediumImpact();
    if (muted) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource('audio/pop.wav'));
    } catch (_) {
      // Ignore audio backend errors on unsupported or test environments.
    }
  }

  void playPeelTick() {
    HapticFeedback.selectionClick();
  }

  void playCelebration() {
    HapticFeedback.heavyImpact();
    playPop();
  }
}
