import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'call_screen.dart';
import 'routine_screen.dart';
import 'settings_screen.dart';
import 'story_screen.dart';
import 'walkthrough_screen.dart';

/// Appa's home. Four big tiles, nothing hidden: no menus, no swipes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final now = s.now;
    final contact = s.todaysContact;
    final call = s.todaysCall;
    final morning = now.hour >= 4 && now.hour < 12;
    final needsSleep = morning && s.todaysSleep == null;

    String callSubtitle;
    if (call != null) {
      final who = s.contactById(call.contactId)?.name ?? '';
      callSubtitle = call.outcome == CallOutcome.called
          ? 'இன்று $who-உடன் பேசினீர்கள்'
          : 'நாளை பார்க்கலாம்';
    } else if (contact != null) {
      callSubtitle = contact.name;
    } else {
      callSubtitle = 'பெயர்களைக் குடும்பத்தினர் சேர்ப்பார்கள்';
    }

    final greeting = '${tamilGreeting(now)}, ${s.displayName}';
    final speak =
        '$greeting. இன்று ${tamilDate(now)}. '
        'இன்றைய கதை, இன்று யாரிடம் பேசலாம், பணம் அனுப்பப் பழகுவோம், தூக்கமும் மாத்திரையும். '
        'எதைத் தேர்ந்தெடுக்க வேண்டுமோ அதை அழுத்துங்கள்.';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: t.headlineMedium),
                        Text(
                          tamilDate(now),
                          style: t.titleMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SpeakButton(text: speak, compact: true),
                ],
              ),
              const SizedBox(height: 20),
              if (needsSleep) ...[
                const SleepCheckInCard(),
                const SizedBox(height: 16),
              ],
              HomeTile(
                icon: Icons.auto_stories,
                title: 'இன்றைய கதை',
                subtitle: s.answeredToday
                    ? 'இன்றைய கதை சொல்லிவிட்டீர்கள்'
                    : 'இன்று ஒரு கேள்வி காத்திருக்கிறது',
                badge: s.unheardReplies > 0
                    ? '${s.unheardReplies} பதில்'
                    : null,
                onTap: () => _open(context, const StoryScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.call,
                title: 'இன்று யாரிடம் பேசலாம்',
                subtitle: callSubtitle,
                color: AppColors.callGreen,
                soft: const Color(0xFFE2F2E5),
                onTap: () => _open(context, const CallScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.currency_rupee,
                title: 'பணம் அனுப்பப் பழகுவோம்',
                subtitle: 'பயிற்சி மட்டும். உண்மையான பணம் போகாது.',
                color: AppColors.practice,
                soft: const Color(0xFFF1E4F6),
                onTap: () => _open(context, const WalkthroughListScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.bedtime,
                title: 'தூக்கமும் மாத்திரையும்',
                subtitle: 'மாத்திரை ${s.reminderSettings.medicine.label}',
                color: AppColors.accent,
                soft: AppColors.accentSoft,
                onTap: () => _open(context, const RoutineScreen()),
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton.icon(
                  onPressed: () => _open(context, const SettingsScreen()),
                  icon: const Icon(
                    Icons.settings,
                    size: 24,
                    color: AppColors.muted,
                  ),
                  label: Text(
                    'குடும்பத்தினருக்கு: அமைப்புகள்',
                    style: t.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    context.read<AppState>().speaker.stop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
