import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Call someone today: one person a day, one tap to call, "not today"
/// accepted without guilt.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool showAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      final c = s.todaysContact;
      if (c != null) s.speaker.speak('இன்று ${c.name}-உடன் பேசலாமா?');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final contact = s.todaysContact;
    final done = s.todaysCall;

    Widget main;
    String speak;
    if (s.contacts.isEmpty) {
      speak = 'பெயர்கள் இன்னும் சேர்க்கவில்லை. குடும்பத்தினர் அமைப்புகளில் சேர்ப்பார்கள்.';
      main = NoteBox(text: speak);
    } else if (done != null) {
      final who = s.contactById(done.contactId)?.name ?? '';
      speak = done.outcome == CallOutcome.called
          ? 'இன்று $who-உடன் பேசினீர்கள். நல்லது.'
          : 'சரி. நாளை பார்க்கலாம்.';
      main = NoteBox(
        icon: done.outcome == CallOutcome.called
            ? Icons.check_circle
            : Icons.wb_sunny_outlined,
        color: AppColors.callGreen,
        text: speak,
      );
    } else {
      final c = contact!;
      speak = 'இன்று ${c.name}-உடன் பேசலாமா?';
      main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F2E5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.callGreen,
                  child: Text(
                    c.name.characters.first,
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  c.name,
                  style: t.displaySmall,
                  textAlign: TextAlign.center,
                ),
                if (c.relation.isNotEmpty)
                  Text(
                    c.relation,
                    style: t.titleMedium?.copyWith(color: AppColors.muted),
                  ),
                if (c.lastCalled != null)
                  Text(
                    'கடைசியாகப் பேசியது: ${tamilDate(c.lastCalled!)}',
                    style: t.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => s.callContact(c),
            icon: const Icon(Icons.call, size: 38),
            label: Text('${c.name}-ஐ அழை'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.callGreen,
              minimumSize: const Size.fromHeight(88),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () async {
              await s.notToday(c);
              await s.speaker.speak('சரி. நாளை பார்க்கலாம்.');
            },
            child: const Text('இன்று வேண்டாம்'),
          ),
        ],
      );
    }

    return AppScreen(
      title: 'இன்று யாரிடம் பேசலாம்',
      speakText: speak,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          main,
          if (s.contacts.isNotEmpty) ...[
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () => setState(() => showAll = !showAll),
              icon: Icon(
                showAll ? Icons.expand_less : Icons.expand_more,
                size: 30,
              ),
              label: Text(showAll ? 'மூடு' : 'வேறு யாரிடமாவது பேச'),
            ),
            if (showAll)
              for (final c in s.contacts) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => s.callContact(c),
                  icon: const Icon(
                    Icons.call,
                    size: 28,
                    color: AppColors.callGreen,
                  ),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      c.relation.isEmpty
                          ? c.name
                          : '${c.name}  ·  ${c.relation}',
                    ),
                  ),
                ),
              ],
          ],
        ],
      ),
    );
  }
}
