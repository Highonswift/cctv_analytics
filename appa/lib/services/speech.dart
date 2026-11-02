import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks Tamil aloud.
///
/// Uses the phone's own text-to-speech engine (Google Speech Services on
/// Android, which ships a free, offline Tamil voice). No paid cloud API. If
/// the Tamil voice is not installed, [tamilAvailable] is false and settings
/// tells the family how to add it.
abstract class Speaker {
  Future<void> init();
  Future<void> speak(String text);
  Future<void> stop();
  bool get tamilAvailable;
}

class DeviceSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  bool _tamil = false;
  bool _ready = false;

  @override
  bool get tamilAvailable => _tamil;

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      final available = await _tts.isLanguageAvailable('ta-IN');
      _tamil = available == true || available == 1;
      await _tts.setLanguage('ta-IN');
      // Slower than default: clear, unhurried, adult. Not baby-talk slow.
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  @override
  Future<void> speak(String text) async {
    await init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Silent speaker for tests and for phones with sound off.
class SilentSpeaker implements Speaker {
  final List<String> spoken = [];
  @override
  Future<void> init() async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  bool get tamilAvailable => true;
}
