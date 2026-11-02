import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';

/// Two screens, no more (roadmap: no onboarding longer than two screens).
/// Ragul does this when installing, sitting beside Appa.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  DeviceRole? role;
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: role == null ? _pickRole(t) : _enterName(t),
        ),
      ),
    );
  }

  Widget _pickRole(TextTheme t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Text('வணக்கம்', style: t.displaySmall),
      const SizedBox(height: 12),
      Text('இந்த போன் யாருடையது?', style: t.headlineSmall),
      const Spacer(),
      FilledButton.icon(
        onPressed: () => setState(() {
          role = DeviceRole.appa;
          name.text = 'அப்பா';
        }),
        icon: const Icon(Icons.person, size: 34),
        label: const Text('அப்பாவின் போன்'),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => setState(() => role = DeviceRole.family),
        icon: const Icon(Icons.family_restroom, size: 34),
        label: const Text('குடும்பத்தினர் போன்'),
      ),
      const SizedBox(height: 8),
      Text(
        'குடும்பத்தினர் போனில்: அப்பாவின் கதைகளைக் கேட்டு, குரல் பதில் அனுப்பலாம்.',
        style: t.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const Spacer(),
    ],
  );

  Widget _enterName(TextTheme t) {
    final appa = role == DeviceRole.appa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          appa ? 'அப்பாவை எப்படி அழைக்கலாம்?' : 'உங்கள் பெயர்',
          style: t.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          appa ? 'இந்தப் பெயரில் தான் குடும்பத்தினர் போனில் தெரியும்.' : 'அப்பா உங்கள் பதிலைக் கேட்கும்போது இந்தப் பெயர் தெரியும். (உதா: ராகுல், அம்மா)',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: name,
          style: t.headlineSmall,
          textCapitalization: TextCapitalization.words,
        ),
        const Spacer(),
        FilledButton(
          onPressed: () async {
            final n = name.text.trim();
            if (n.isEmpty) return;
            await context.read<AppState>().completeSetup(role: role!, name: n);
          },
          child: const Text('தொடங்கலாம்'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => role = null),
          child: const Text('திரும்ப'),
        ),
      ],
    );
  }
}
