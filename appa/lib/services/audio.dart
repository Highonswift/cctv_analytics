import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records and plays voice notes (stories and family replies).
/// Files are AAC in .m4a, about 0.5 MB a minute, kept in app storage.
abstract class VoiceAudio {
  Future<bool> ensureMicPermission();
  Future<void> startRecording(String fileName);
  Future<String?> stopRecording();
  Future<void> cancelRecording();
  Future<void> play(String pathOrUrl);
  Future<void> stopPlayback();
  Stream<bool> get playing;
  Future<String> filePath(String fileName);
  Future<void> dispose();
}

class DeviceVoiceAudio implements VoiceAudio {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<bool> ensureMicPermission() => _recorder.hasPermission();

  @override
  Future<String> filePath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final voice = Directory('${dir.path}/voice');
    if (!voice.existsSync()) voice.createSync(recursive: true);
    return '${voice.path}/$fileName';
  }

  @override
  Future<void> startRecording(String fileName) async {
    await stopPlayback();
    final path = await filePath(fileName);
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: path,
    );
  }

  @override
  Future<String?> stopRecording() => _recorder.stop();

  @override
  Future<void> cancelRecording() => _recorder.cancel();

  @override
  Future<void> play(String pathOrUrl) async {
    try {
      await _player.stop();
      if (pathOrUrl.startsWith('http')) {
        await _player.setUrl(pathOrUrl);
      } else {
        await _player.setFilePath(pathOrUrl);
      }
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Playback failed: $e');
    }
  }

  @override
  Future<void> stopPlayback() => _player.stop();

  @override
  Stream<bool> get playing => _player.playerStateStream.map(
    (s) => s.playing && s.processingState != ProcessingState.completed,
  );

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}

/// In-memory stand-in for tests.
class FakeVoiceAudio implements VoiceAudio {
  String? recordingName;
  final List<String> played = [];
  final _playing = StreamController<bool>.broadcast();

  @override
  Future<bool> ensureMicPermission() async => true;
  @override
  Future<String> filePath(String fileName) async => '/fake/$fileName';
  @override
  Future<void> startRecording(String fileName) async =>
      recordingName = fileName;
  @override
  Future<String?> stopRecording() async {
    final n = recordingName;
    recordingName = null;
    return n == null ? null : '/fake/$n';
  }

  @override
  Future<void> cancelRecording() async => recordingName = null;
  @override
  Future<void> play(String pathOrUrl) async => played.add(pathOrUrl);
  @override
  Future<void> stopPlayback() async {}
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Future<void> dispose() async => _playing.close();
}
