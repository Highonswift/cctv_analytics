import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recorder.dart';

/// Story of the day: one question, spoken aloud; he answers by voice.
/// Family hear it and reply with a voice note.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  bool justSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      if (!s.answeredToday)
        s.speaker.speak('இன்றைய கேள்வி. ${s.todaysPrompt.tamil}');
      s.pullReplies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final prompt = s.todaysPrompt;

    return AppScreen(
      title: 'இன்றைய கதை',
      speakText: 'இன்றைய கேள்வி. ${prompt.tamil}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(prompt.tamil, style: t.headlineSmall),
          ),
          const SizedBox(height: 28),
          if (justSaved)
            const NoteBox(
              icon: Icons.favorite,
              text: 'நன்றி. உங்கள் கதை சேமிக்கப்பட்டது. குடும்பத்தினர் கேட்பார்கள்.',
            )
          else
            VoiceRecorder(
              fileName: 'story-${DateTime.now().millisecondsSinceEpoch}.m4a',
              startLabel: s.answeredToday
                  ? 'இன்னொரு முறை சொல்ல அழுத்துங்கள்'
                  : 'பதில் சொல்ல அழுத்துங்கள்',
              saveLabel: 'கதையைச் சேமி',
              onSaved: (path) async {
                await s.saveStory(audioPath: path, prompt: prompt);
                await s.speaker.speak('நன்றி. உங்கள் கதை சேமிக்கப்பட்டது.');
                if (mounted) setState(() => justSaved = true);
              },
            ),
          if (justSaved) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => justSaved = false),
              child: const Text('இன்னொன்று சொல்ல'),
            ),
          ],
          const SizedBox(height: 36),
          if (s.stories.isNotEmpty) ...[
            Text('உங்கள் கதைகள் (${s.stories.length})', style: t.titleLarge),
            const SizedBox(height: 12),
            for (final story in s.stories) ...[
              _StoryTile(story: story),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unheard = story.unheardReplies;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StoryDetailScreen(id: story.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.graphic_eq, size: 34, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tamilDate(story.createdAt), style: t.titleMedium),
                    Text(
                      story.promptText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium,
                    ),
                    if (story.replies.isNotEmpty)
                      Text(
                        unheard > 0
                            ? '$unheard புதிய பதில்'
                            : '${story.replies.length} பதில்',
                        style: t.bodyMedium?.copyWith(
                          color: unheard > 0
                              ? AppColors.accent
                              : AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryDetailScreen extends StatelessWidget {
  const StoryDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final story = s.stories.where((x) => x.id == id).firstOrNull;
    if (story == null) {
      return const AppScreen(title: 'கதை', body: Text('இந்தக் கதை இல்லை.'));
    }

    return AppScreen(
      title: tamilDate(story.createdAt),
      speakText: story.promptText,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(story.promptText, style: t.headlineSmall),
          const SizedBox(height: 20),
          if (story.localAudioPath != null)
            FilledButton.icon(
              onPressed: () => s.audio.play(story.localAudioPath!),
              icon: const Icon(Icons.play_arrow_rounded, size: 38),
              label: const Text('உங்கள் கதையைக் கேளுங்கள்'),
            ),
          const SizedBox(height: 28),
          Text('குடும்பத்தினர் பதில்கள்', style: t.titleLarge),
          const SizedBox(height: 12),
          if (story.replies.isEmpty)
            Text(
              'இன்னும் பதில் இல்லை.',
              style: t.bodyLarge?.copyWith(color: AppColors.muted),
            ),
          for (final r in story.replies) ...[
            OutlinedButton.icon(
              onPressed: r.localAudioPath == null
                  ? null
                  : () {
                      s.audio.play(r.localAudioPath!);
                      if (!r.listened) s.markReplyHeard(story.id, r.id);
                    },
              icon: Icon(
                r.listened ? Icons.play_arrow_rounded : Icons.fiber_new,
                size: 34,
              ),
              label: Text('${r.authorName} சொன்னது'),
              style: r.listened
                  ? null
                  : OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent, width: 2),
                    ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'குடும்பத்தினர் இந்த போனிலேயே பதில் சொல்ல',
            style: t.titleMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          _LocalReply(storyId: story.id),
        ],
      ),
    );
  }
}

/// For a family member sitting beside him (works with no internet).
class _LocalReply extends StatefulWidget {
  const _LocalReply({required this.storyId});
  final String storyId;
  @override
  State<_LocalReply> createState() => _LocalReplyState();
}

class _LocalReplyState extends State<_LocalReply> {
  final name = TextEditingController();
  bool open = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => open = true),
        icon: const Icon(Icons.record_voice_over, size: 30),
        label: const Text('பதில் பதிவு செய்'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'உங்கள் பெயர்'),
        ),
        const SizedBox(height: 16),
        VoiceRecorder(
          fileName: 'reply-local-${DateTime.now().millisecondsSinceEpoch}.m4a',
          startLabel: 'பதில் சொல்ல அழுத்துங்கள்',
          saveLabel: 'பதிலைச் சேமி',
          onSaved: (path) async {
            final author = name.text.trim().isEmpty
                ? 'குடும்பம்'
                : name.text.trim();
            await context.read<AppState>().addLocalReply(
              storyId: widget.storyId,
              author: author,
              audioPath: path,
            );
            if (mounted) setState(() => open = false);
          },
        ),
      ],
    );
  }
}
