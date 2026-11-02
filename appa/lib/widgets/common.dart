import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Every screen: a big labelled back button (no gestures to discover),
/// a title, and an optional "listen" button that reads the screen aloud.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.title,
    required this.body,
    this.speakText,
    this.showBack = true,
    this.scroll = true,
  });

  final String title;
  final Widget body;
  final String? speakText;
  final bool showBack;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: body,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: showBack ? 132 : 0,
        leading: showBack ? const _BackButton() : null,
        title: Text(title, maxLines: 2),
        actions: [
          if (speakText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SpeakButton(text: speakText!, compact: true),
            ),
        ],
      ),
      body: SafeArea(
        child: scroll ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        onPressed: () {
          context.read<AppState>().speaker.stop();
          Navigator.of(context).maybePop();
        },
        icon: const Icon(Icons.arrow_back, size: 30),
        label: const Text('திரும்ப'),
        style: TextButton.styleFrom(foregroundColor: AppColors.ink),
      ),
    );
  }
}

/// Reads [text] aloud in Tamil.
class SpeakButton extends StatelessWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.compact = false,
    this.label = 'கேளுங்கள்',
  });
  final String text;
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    void speak() => context.read<AppState>().speaker.speak(text);
    if (compact) {
      return TextButton.icon(
        onPressed: speak,
        icon: const Icon(Icons.volume_up, size: 32),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      );
    }
    return OutlinedButton.icon(
      onPressed: speak,
      icon: const Icon(Icons.volume_up, size: 32),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

/// A large tile on the home screen.
class HomeTile extends StatelessWidget {
  const HomeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.primary,
    this.soft = AppColors.primarySoft,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color soft;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: soft,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: color,
                  child: Icon(icon, size: 38, color: Colors.white),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: t.bodyMedium?.copyWith(color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A calm boxed message (no pop-ups that vanish on a timer).
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.color = AppColors.primary,
  });
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

String tamilDate(DateTime d) {
  const months = [
    'ஜனவரி',
    'பிப்ரவரி',
    'மார்ச்',
    'ஏப்ரல்',
    'மே',
    'ஜூன்',
    'ஜூலை',
    'ஆகஸ்ட்',
    'செப்டம்பர்',
    'அக்டோபர்',
    'நவம்பர்',
    'டிசம்பர்',
  ];
  const days = [
    'திங்கள்',
    'செவ்வாய்',
    'புதன்',
    'வியாழன்',
    'வெள்ளி',
    'சனி',
    'ஞாயிறு',
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

String tamilGreeting(DateTime d) {
  if (d.hour < 12) return 'காலை வணக்கம்';
  if (d.hour < 16) return 'மதிய வணக்கம்';
  if (d.hour < 19) return 'மாலை வணக்கம்';
  return 'இரவு வணக்கம்';
}
