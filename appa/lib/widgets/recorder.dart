import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// One big round button: tap to start recording, tap again to stop. Then
/// listen back, keep, or record again. Used for stories and for replies.
class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({
    super.key,
    required this.fileName,
    required this.onSaved,
    this.saveLabel = 'சேமி',
    this.startLabel = 'பதிவு செய்ய அழுத்துங்கள்',
  });

  final String fileName;
  final Future<void> Function(String path) onSaved;
  final String saveLabel;
  final String startLabel;

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

enum _Phase { idle, recording, review, saving }

class _VoiceRecorderState extends State<VoiceRecorder> {
  _Phase phase = _Phase.idle;
  String? path;
  Timer? _timer;
  int seconds = 0;
  String? problem;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final s = context.read<AppState>();
    await s.speaker.stop();
    final ok = await s.audio.ensureMicPermission();
    if (!ok) {
      setState(
        () => problem = 'மைக் அனுமதி தேவை. அமைப்புகளில் மைக்கை அனுமதியுங்கள்.',
      );
      return;
    }
    try {
      await s.audio.startRecording(widget.fileName);
    } catch (e) {
      setState(() => problem = 'பதிவு தொடங்கவில்லை. மீண்டும் முயற்சிக்கலாம்.');
      return;
    }
    setState(() {
      problem = null;
      phase = _Phase.recording;
      seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final p = await context.read<AppState>().audio.stopRecording();
    setState(() {
      path = p;
      phase = p == null ? _Phase.idle : _Phase.review;
    });
  }

  Future<void> _save() async {
    final p = path;
    if (p == null) return;
    setState(() => phase = _Phase.saving);
    await widget.onSaved(p);
    if (mounted) {
      setState(() {
        phase = _Phase.idle;
        path = null;
      });
    }
  }

  String get _clock =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final audio = context.read<AppState>().audio;

    switch (phase) {
      case _Phase.idle:
      case _Phase.recording:
        final rec = phase == _Phase.recording;
        return Column(
          children: [
            Semantics(
              button: true,
              label: rec ? 'நிறுத்து' : widget.startLabel,
              child: GestureDetector(
                onTap: rec ? _stop : _start,
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rec ? AppColors.accent : AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (rec ? AppColors.accent : AppColors.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: rec ? 28 : 12,
                        spreadRadius: rec ? 6 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    rec ? Icons.stop_rounded : Icons.mic,
                    size: 84,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              rec
                  ? 'பதிவாகிறது  $_clock\nமுடிந்ததும் மீண்டும் அழுத்துங்கள்'
                  : widget.startLabel,
              textAlign: TextAlign.center,
              style: t.titleMedium,
            ),
            if (problem != null) ...[
              const SizedBox(height: 12),
              Text(
                problem!,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppColors.accent),
              ),
            ],
          ],
        );
      case _Phase.review:
      case _Phase.saving:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () => audio.play(path!),
              icon: const Icon(Icons.play_arrow_rounded, size: 36),
              label: const Text('கேட்டுப் பாருங்கள்'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: phase == _Phase.saving ? null : _save,
              icon: const Icon(Icons.check_rounded, size: 34),
              label: Text(widget.saveLabel),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: phase == _Phase.saving
                  ? null
                  : () => setState(() {
                      phase = _Phase.idle;
                      path = null;
                    }),
              icon: const Icon(Icons.replay, size: 28),
              label: const Text('மீண்டும் பதிவு செய்'),
            ),
          ],
        );
    }
  }
}
