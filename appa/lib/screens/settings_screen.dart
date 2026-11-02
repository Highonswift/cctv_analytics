import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'routine_screen.dart';

/// Settings for the family (Ragul sets these up beside Appa). Plain list,
/// nothing hidden. Appa can open it too; nothing here happens behind his back.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final appa = s.role == DeviceRole.appa;

    return AppScreen(
      title: 'அமைப்புகள்',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (appa) ...[
            _Section('பேச வேண்டியவர்கள்'),
            Text(
              'தினமும் ஒருவரை அழைக்க நினைவூட்டும். நீண்ட நாள் பேசாதவர் முதலில் வருவார்.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            for (final c in s.contacts)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  minVerticalPadding: 14,
                  title: Text(c.name, style: t.titleMedium),
                  subtitle: Text(
                    [
                      c.relation,
                      c.phone,
                    ].where((x) => x.isNotEmpty).join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'மாற்று',
                    icon: const Icon(Icons.edit, size: 28),
                    onPressed: () => _editContact(context, c),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _editContact(context, null),
              icon: const Icon(Icons.person_add, size: 28),
              label: const Text('ஒருவரைச் சேர்'),
            ),
            _Section('நினைவூட்டல் (தினமும் மூன்று மட்டும்)'),
            _ReminderEditor(settings: s.reminderSettings),
            _Section('தூக்கம் (கடந்த ஏழு நாள்)'),
            SleepWeek(ratings: s.lastWeekSleep, today: s.now),
            _Section('தமிழ்க் குரல்'),
            Text(
              s.speaker.tamilAvailable
                  ? 'தமிழ்க் குரல் இந்த போனில் உள்ளது.'
                  : 'தமிழ்க் குரல் இன்னும் நிறுவப்படவில்லை. Settings → Accessibility → Text-to-speech → '
                        'Speech Services by Google → Install voice data → தமிழ் (Tamil). இலவசம், இணையம் இல்லாமலும் வேலை செய்யும்.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 10),
            const SpeakButton(
              text: 'வணக்கம். இது தமிழ்க் குரல் சோதனை.',
              label: 'குரலைச் சோதி',
            ),
          ],
          _Section('குடும்பத்துடன் பகிர்தல் (விருப்பம்)'),
          _SyncSetup(appa: appa),
          _Section('இந்த போன்'),
          Text(
            '${appa ? 'அப்பாவின் போன்' : 'குடும்பத்தினர் போன்'} · ${s.displayName}',
            style: t.bodyLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _editContact(BuildContext context, Contact? existing) async {
    final s = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final relation = TextEditingController(text: existing?.relation ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'ஒருவரைச் சேர்' : 'மாற்று'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'பெயர்'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: const InputDecoration(labelText: 'போன் எண்'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relation,
                decoration: const InputDecoration(
                  labelText: 'உறவு (உதா: டிப்போ நண்பர்)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                s.removeContact(existing.id);
                Navigator.pop(ctx);
              },
              child: const Text(
                'நீக்கு',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ரத்து'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () {
              if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
              s.saveContact(
                (existing ?? Contact(id: s.newId(), name: '', phone: ''))
                    .copyWith(
                      name: name.text.trim(),
                      phone: phone.text.trim(),
                      relation: relation.text.trim(),
                    ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('சேமி'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _ReminderEditor extends StatelessWidget {
  const _ReminderEditor({required this.settings});
  final ReminderSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();

    Future<void> pick(
      TimeOfDayMinutes current,
      ReminderSettings Function(TimeOfDayMinutes) apply,
    ) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      );
      if (picked != null)
        await s.updateReminders(
          apply(TimeOfDayMinutes(picked.hour, picked.minute)),
        );
    }

    Widget row(
      String label,
      TimeOfDayMinutes time,
      ReminderSettings Function(TimeOfDayMinutes) apply,
    ) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        minVerticalPadding: 14,
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        trailing: Text(
          time.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () => pick(time, apply),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: settings.enabled,
          onChanged: (v) => s.updateReminders(settings.copyWith(enabled: v)),
          title: const Text(
            'நினைவூட்டல் இயக்கத்தில்',
            style: TextStyle(fontSize: 20),
          ),
        ),
        row(
          'காலை தூக்கக் கேள்வி',
          settings.morningCheckIn,
          (t) => settings.copyWith(morningCheckIn: t),
        ),
        row(
          'மாத்திரை',
          settings.medicine,
          (t) => settings.copyWith(medicine: t),
        ),
        row(
          'இரவு ஓய்வு',
          settings.windDown,
          (t) => settings.copyWith(windDown: t),
        ),
        const SizedBox(height: 6),
        _MedicineName(initial: settings.medicineName),
      ],
    );
  }
}

class _MedicineName extends StatefulWidget {
  const _MedicineName({required this.initial});
  final String initial;
  @override
  State<_MedicineName> createState() => _MedicineNameState();
}

class _MedicineNameState extends State<_MedicineName> {
  late final c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: c,
    decoration: const InputDecoration(
      labelText: 'மாத்திரையின் பெயர் (விருப்பம்)',
    ),
    onSubmitted: (v) {
      final s = context.read<AppState>();
      s.updateReminders(s.reminderSettings.copyWith(medicineName: v.trim()));
    },
    onTapOutside: (_) {
      final s = context.read<AppState>();
      if (c.text.trim() != s.reminderSettings.medicineName) {
        s.updateReminders(
          s.reminderSettings.copyWith(medicineName: c.text.trim()),
        );
      }
      FocusScope.of(context).unfocus();
    },
  );
}

/// Supabase project URL + publishable key, and the household code.
class _SyncSetup extends StatefulWidget {
  const _SyncSetup({required this.appa});
  final bool appa;
  @override
  State<_SyncSetup> createState() => _SyncSetupState();
}

class _SyncSetupState extends State<_SyncSetup> {
  late final url = TextEditingController(
    text: context.read<AppState>().store.syncUrl ?? '',
  );
  late final key = TextEditingController(
    text: context.read<AppState>().store.syncKey ?? '',
  );
  final code = TextEditingController();

  @override
  void dispose() {
    url.dispose();
    key.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final joined = s.sync.connected;

    if (joined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteBox(
            icon: Icons.cloud_done,
            color: AppColors.callGreen,
            text: widget.appa
                ? 'பகிர்தல் இயக்கத்தில். குடும்பக் குறியீடு: ${s.sync.householdCode}\n'
                      'குடும்பத்தினர் தங்கள் போனில் இந்தக் குறியீட்டைப் போட்டுச் சேரலாம். '
                      'அவர்கள் உங்கள் கதைகளை மட்டும் கேட்பார்கள்; வேறு எதுவும் பகிரப்படாது.'
                : 'பகிர்தல் இயக்கத்தில். குடும்பக் குறியீடு: ${s.sync.householdCode}',
          ),
          if (s.syncError != null) ...[
            const SizedBox(height: 8),
            Text(
              'கடைசிப் பிழை: ${s.syncError}',
              style: t.bodyMedium?.copyWith(color: AppColors.accent),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'இல்லாமலும் ஆப் முழுவதும் வேலை செய்யும். குடும்பத்தினர் தங்கள் போனில் கதைகளைக் கேட்க, '
          'இலவச Supabase project ஒன்று வேண்டும் (README பார்க்கவும்).',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: url,
          decoration: const InputDecoration(labelText: 'Supabase URL'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: key,
          decoration: const InputDecoration(
            labelText: 'Publishable (anon) key',
          ),
        ),
        if (!widget.appa) ...[
          const SizedBox(height: 10),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'அப்பாவின் போனில் உள்ள குடும்பக் குறியீடு',
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: s.syncing
              ? null
              : () => s.setUpSync(
                  url: url.text,
                  key: key.text,
                  joinCode: widget.appa ? null : code.text,
                ),
          child: Text(
            s.syncing
                ? 'இணைக்கிறது…'
                : (widget.appa ? 'பகிர்தலைத் தொடங்கு' : 'சேர்'),
          ),
        ),
        if (s.syncError != null) ...[
          const SizedBox(height: 8),
          Text(
            'இணைக்க முடியவில்லை: ${s.syncError}',
            style: t.bodyMedium?.copyWith(color: AppColors.accent),
          ),
        ],
      ],
    );
  }
}
