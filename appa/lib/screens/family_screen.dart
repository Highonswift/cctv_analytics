import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/sync.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recorder.dart';
import 'settings_screen.dart';

/// Family phone: hear Appa's stories and send a voice reply.
class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key});
  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppState>().loadFamilyStories(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final seen = s.seenFamilyStories;

    return Scaffold(
      appBar: AppBar(
        title: Text('அப்பாவின் கதைகள்'),
        actions: [
          IconButton(
            tooltip: 'அமைப்புகள்',
            icon: const Icon(Icons.settings, size: 30),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: s.loadFamilyStories,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!s.sync.connected)
                const NoteBox(
                  text:
                      'அப்பாவின் கதைகளைக் கேட்க, அமைப்புகளில் Supabase விவரங்களும் '
                      'அப்பாவின் போனில் உள்ள குடும்பக் குறியீடும் போடுங்கள்.',
                )
              else ...[
                Text(
                  'வணக்கம் ${s.displayName}. ஒவ்வொரு வாரமும் குறைந்தது இரண்டு கதைக்குப் பதில் சொல்லுங்கள்; '
                  'அவர் கவனிப்பார்.',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                if (s.syncing && s.familyStories.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                if (!s.syncing && s.familyStories.isEmpty)
                  const NoteBox(
                    text: 'இன்னும் கதைகள் இல்லை. அப்பா முதல் கதையைச் சொன்னதும் இங்கே வரும்.',
                  ),
                for (final story in s.familyStories) ...[
                  Card(
                    child: ListTile(
                      minVerticalPadding: 16,
                      leading: Icon(
                        seen.contains(story.id)
                            ? Icons.graphic_eq
                            : Icons.fiber_new,
                        size: 34,
                        color: seen.contains(story.id)
                            ? AppColors.primary
                            : AppColors.accent,
                      ),
                      title: Text(story.promptText, style: t.titleMedium),
                      subtitle: Text(
                        '${tamilDate(story.createdAt)}'
                        '${story.replyAuthors.isEmpty ? '' : ' · பதில்: ${story.replyAuthors.join(', ')}'}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FamilyStoryScreen(story: story),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyStoryScreen extends StatefulWidget {
  const FamilyStoryScreen({super.key, required this.story});
  final RemoteStory story;
  @override
  State<FamilyStoryScreen> createState() => _FamilyStoryScreenState();
}

class _FamilyStoryScreenState extends State<FamilyStoryScreen> {
  bool sent = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppState>().markFamilyStorySeen(widget.story.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;

    return AppScreen(
      title: tamilDate(widget.story.createdAt),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.story.promptText, style: t.headlineSmall),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final url = await s.sync.signedUrl(widget.story.audioPath);
              await s.audio.play(url);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 38),
            label: const Text('அப்பாவின் கதையைக் கேளுங்கள்'),
          ),
          const SizedBox(height: 32),
          Text('குரல் பதில்', style: t.titleLarge),
          const SizedBox(height: 6),
          Text(
            'ஒரு கேள்வி கேளுங்கள், அல்லது உங்களுக்கு என்ன பிடித்தது என்று சொல்லுங்கள்.',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (sent)
            const NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: 'அனுப்பப்பட்டது. அப்பா கேட்பார்.',
            )
          else
            VoiceRecorder(
              fileName:
                  'family-reply-${DateTime.now().millisecondsSinceEpoch}.m4a',
              startLabel: 'பதில் சொல்ல அழுத்துங்கள்',
              saveLabel: 'அனுப்பு',
              onSaved: (path) async {
                final ok = await s.sendFamilyReply(
                  storyId: widget.story.id,
                  audioPath: path,
                );
                if (mounted) {
                  setState(() {
                    sent = ok;
                    failed = !ok;
                  });
                }
              },
            ),
          if (failed) ...[
            const SizedBox(height: 10),
            Text(
              'அனுப்ப முடியவில்லை. இணையம் உள்ளதா என்று பார்த்து மீண்டும் முயற்சிக்கவும்.',
              style: t.bodyMedium?.copyWith(color: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
