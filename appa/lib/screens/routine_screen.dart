import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

const sleepLabels = {
  SleepRating.good: 'நன்றாகத் தூங்கினேன்',
  SleepRating.okay: 'பரவாயில்லை',
  SleepRating.bad: 'சரியாகத் தூங்கவில்லை',
};

const _sleepShort = {
  SleepRating.good: 'நன்று',
  SleepRating.okay: 'பரவாயில்லை',
  SleepRating.bad: 'சரியில்லை',
};

const _sleepColors = {
  SleepRating.good: AppColors.callGreen,
  SleepRating.okay: Color(0xFFB8860B),
  SleepRating.bad: AppColors.accent,
};

/// Morning "how did you sleep?" — one tap. Shown on the home screen in the
/// morning and on the routine screen.
class SleepCheckInCard extends StatelessWidget {
  const SleepCheckInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final today = s.todaysSleep;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('நேற்று இரவு தூக்கம் எப்படி?', style: t.titleLarge),
              ),
              const SpeakButton(
                text: 'நேற்று இரவு தூக்கம் எப்படி இருந்தது?',
                compact: true,
                label: '',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (today != null)
            Text(
              'இன்று சொன்னது: ${sleepLabels[today.rating]}. நன்றி.',
              style: t.bodyLarge,
            )
          else
            for (final r in SleepRating.values) ...[
              FilledButton(
                onPressed: () async {
                  await s.rateSleep(r);
                  await s.speaker.speak('நன்றி.');
                },
                style: FilledButton.styleFrom(backgroundColor: _sleepColors[r]),
                child: Text(sleepLabels[r]!),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Last seven mornings in a row of labelled dots.
class SleepWeek extends StatelessWidget {
  const SleepWeek({super.key, required this.ratings, required this.today});
  final List<SleepRating?> ratings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    const dayShort = ['தி', 'செ', 'பு', 'வி', 'வெ', 'ச', 'ஞா'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < ratings.length; i++)
          Builder(
            builder: (context) {
              final d = DateTime(
                today.year,
                today.month,
                today.day,
              ).subtract(Duration(days: ratings.length - 1 - i));
              final r = ratings[i];
              return Semantics(
                label: r == null ? 'பதில் இல்லை' : _sleepShort[r],
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r == null ? Colors.transparent : _sleepColors[r],
                        border: Border.all(
                          color: r == null ? AppColors.muted : _sleepColors[r]!,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayShort[d.weekday - 1],
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final r = s.reminderSettings;
    final med = r.medicineName.trim().isEmpty
        ? 'காலை மாத்திரை'
        : r.medicineName.trim();

    final speak =
        'மாத்திரை நேரம் ${r.medicine.label}. இரவு ஓய்வு நேரம் ${r.windDown.label}. '
        'காலை ${r.morningCheckIn.label} மணிக்கு தூக்கம் பற்றி ஒரு கேள்வி.';

    return AppScreen(
      title: 'தூக்கமும் மாத்திரையும்',
      speakText: speak,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SleepCheckInCard(),
          const SizedBox(height: 24),
          Text('கடந்த ஏழு நாள் தூக்கம்', style: t.titleLarge),
          const SizedBox(height: 12),
          SleepWeek(ratings: s.lastWeekSleep, today: s.now),
          const SizedBox(height: 8),
          Text(
            'பச்சை: நன்று · மஞ்சள்: பரவாயில்லை · சிவப்பு: சரியில்லை',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          Text('தினசரி நினைவூட்டல்', style: t.titleLarge),
          const SizedBox(height: 12),
          _ReminderRow(
            icon: Icons.wb_sunny,
            label: 'தூக்கக் கேள்வி',
            time: r.morningCheckIn.label,
          ),
          _ReminderRow(
            icon: Icons.medication,
            label: med,
            time: r.medicine.label,
          ),
          _ReminderRow(
            icon: Icons.bedtime,
            label: 'இரவு ஓய்வு',
            time: r.windDown.label,
          ),
          const SizedBox(height: 12),
          if (!r.enabled)
            const NoteBox(text: 'நினைவூட்டல் இப்போது நிறுத்தப்பட்டுள்ளது.')
          else
            Text(
              'நேரத்தை மாற்ற குடும்பத்தினரிடம் சொல்லுங்கள், அல்லது அமைப்புகளில் மாற்றலாம்.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('இரவு நல்ல தூக்கத்துக்கு', style: t.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '• மாலை ஆறு மணிக்குப் பிறகு டீ, காபி வேண்டாம்\n'
                  '• தூங்கும் முன் அரை மணி நேரம் டிவி அணைக்கலாம்\n'
                  '• போனை படுக்கையறைக்கு வெளியே வைக்கலாம்',
                  style: t.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.label,
    required this.time,
  });
  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 32, color: AppColors.accent),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: t.titleMedium)),
          Text(time, style: t.titleMedium),
        ],
      ),
    );
  }
}
