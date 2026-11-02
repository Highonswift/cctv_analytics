import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/walkthrough.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// List of practice walkthroughs.
class WalkthroughListScreen extends StatelessWidget {
  const WalkthroughListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    return AppScreen(
      title: 'பணம் அனுப்பப் பழகுவோம்',
      speakText:
          'இங்கே பயிற்சி மட்டும். உண்மையான பணம் எங்கும் போகாது. '
          'எத்தனை தடவை வேண்டுமானாலும் செய்து பார்க்கலாம்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoteBox(
            icon: Icons.shield_outlined,
            color: AppColors.practice,
            text: 'இங்கே பயிற்சி மட்டும். உண்மையான பணம் எங்கும் போகாது. எத்தனை தடவை வேண்டுமானாலும் செய்து பார்க்கலாம்.',
          ),
          const SizedBox(height: 20),
          for (final w in phaseOneWalkthroughs) ...[
            HomeTile(
              icon: w.id == 'upi-send'
                  ? Icons.send_rounded
                  : Icons.account_balance_wallet,
              title: w.title,
              subtitle: s.completedWalkthroughs.contains(w.id)
                  ? '${w.summary}\n✓ செய்து பார்த்தீர்கள்'
                  : w.summary,
              color: AppColors.practice,
              soft: const Color(0xFFF1E4F6),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WalkthroughScreen(walkthrough: w),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          Text(
            'அடுத்து வருபவை: WhatsApp, வங்கி ஆப், பஸ் டிக்கெட்.',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Runs one walkthrough on a mock phone screen.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key, required this.walkthrough});
  final Walkthrough walkthrough;
  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  late final WalkthroughSession session = WalkthroughSession(
    widget.walkthrough,
  );
  String? hint;
  bool firstTime = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _say(session.narration(session.step)),
    );
  }

  void _say(String text) => context.read<AppState>().speaker.speak(text);

  Future<void> _act(MockAction a) async {
    final r = session.handle(a);
    if (!r.advanced) {
      setState(() => hint = r.message);
      if (r.message != null) _say(r.message!);
      return;
    }
    if (session.completed) {
      final first = await context.read<AppState>().markWalkthroughDone(
        widget.walkthrough.id,
      );
      setState(() {
        hint = null;
        firstTime = first;
      });
      _say(
        first
            ? 'நீங்களே முழுவதும் செய்து முடித்தீர்கள். அடுத்த முறை உண்மையான ஆப்பிலும் இதே மாதிரி தான்.'
            : 'முடிந்தது.',
      );
      return;
    }
    setState(() => hint = null);
    if (r.message != null) _say(r.message!);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final step = session.step;

    return AppScreen(
      title: widget.walkthrough.title,
      speakText: session.completed ? 'முடிந்தது' : session.narration(step),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.practice,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'பயிற்சி — உண்மையான பணம் இல்லை',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (session.completed) ...[
            NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: firstTime
                  ? 'நீங்களே முழுவதும் செய்து முடித்தீர்கள். அடுத்த முறை உண்மையான ஆப்பிலும் இதே மாதிரி தான்.'
                  : 'முடிந்தது.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  session.restart();
                  firstTime = false;
                  hint = null;
                });
                _say(session.narration(session.step));
              },
              icon: const Icon(Icons.replay, size: 32),
              label: const Text('மீண்டும் செய்து பார்'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('போதும்'),
            ),
          ] else ...[
            Text(
              'படி ${session.index + 1} / ${widget.walkthrough.steps.length}',
              style: t.titleMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(session.narration(step), style: t.bodyLarge),
            if (hint != null) ...[
              const SizedBox(height: 10),
              NoteBox(
                text: hint!,
                icon: Icons.touch_app,
                color: AppColors.accent,
              ),
            ],
            const SizedBox(height: 16),
            MockPhone(session: session, onAction: _act),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  session.restart();
                  hint = null;
                });
                _say(session.narration(session.step));
              },
              icon: const Icon(Icons.replay, size: 26),
              label: const Text('முதலிலிருந்து'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A plain, generic payment app drawn inside a phone frame. Deliberately not
/// a copy of any real app's branding: it teaches the shape of the flow (pay,
/// pick person, amount, check, PIN, tick), which is the same in every UPI app.
class MockPhone extends StatelessWidget {
  const MockPhone({super.key, required this.session, required this.onAction});
  final WalkthroughSession session;
  final void Function(MockAction) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.ink, width: 6),
      ),
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 420),
      child: switch (session.step.screen) {
        MockScreen.intro => _intro(),
        MockScreen.home => _home(),
        MockScreen.contacts => _contacts(),
        MockScreen.amount => _AmountEntry(onAction: onAction),
        MockScreen.confirm => _confirm(),
        MockScreen.pin => _PinEntry(onAction: onAction),
        MockScreen.success => _success(),
        MockScreen.balance => _balance(),
      },
    );
  }

  bool _isTarget(String id) => session.step.target == id;

  Widget _btn(
    String id,
    String label,
    IconData icon, {
    Color color = AppColors.primary,
  }) => _Glow(
    on: _isTarget(id),
    child: FilledButton.icon(
      onPressed: () => onAction(Tap(id)),
      icon: Icon(icon, size: 30),
      label: Text(label),
      style: FilledButton.styleFrom(backgroundColor: color),
    ),
  );

  Widget _intro() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.school, size: 80, color: AppColors.practice),
      const SizedBox(height: 16),
      const Text(
        'பயிற்சி',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 32),
      _btn(
        'start',
        'தொடங்கு',
        Icons.play_arrow_rounded,
        color: AppColors.practice,
      ),
    ],
  );

  Widget _home() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'UPI பயிற்சி ஆப்',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'வணக்கம்!',
        style: TextStyle(fontSize: 20, color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _homeIcon('scan', 'QR ஸ்கேன்', Icons.qr_code_scanner),
          ),
          const SizedBox(width: 10),
          Expanded(child: _homeIcon('pay', 'பணம் அனுப்பு', Icons.send_rounded)),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _homeIcon(
              'balance',
              'இருப்பு பார்',
              Icons.account_balance_wallet,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _homeIcon('history', 'பழைய பரிவர்த்தனை', Icons.history),
          ),
        ],
      ),
    ],
  );

  Widget _homeIcon(String id, String label, IconData icon) => _Glow(
    on: _isTarget(id),
    child: Material(
      color: const Color(0xFFEFF3F8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onAction(Tap(id)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _contacts() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'யாருக்கு அனுப்ப?',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      for (final (id, name) in [
        ('other1', 'கணேசன்'),
        ('contact', practiceRecipient),
        ('other2', 'லட்சுமி'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Glow(
            on: _isTarget(id),
            child: Material(
              color: const Color(0xFFEFF3F8),
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                minVerticalPadding: 18,
                onTap: () => onAction(Tap(id)),
                leading: CircleAvatar(
                  radius: 26,
                  child: Text(
                    name.characters.first,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  '98xxx xxxxx',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _confirm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'சரிபார்க்கவும்',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 18),
      const Text(
        'பெயர்',
        style: TextStyle(fontSize: 18, color: AppColors.muted),
      ),
      const Text(
        practiceRecipient,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      const Text(
        'தொகை',
        style: TextStyle(fontSize: 18, color: AppColors.muted),
      ),
      Text(
        '₹ ${session.amount ?? 0}',
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 28),
      _btn('send', 'அனுப்பு', Icons.send_rounded),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => onAction(const Tap('cancel')),
        child: const Text('ரத்து'),
      ),
    ],
  );

  Widget _success() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.check_circle, size: 110, color: AppColors.callGreen),
      const SizedBox(height: 10),
      Text(
        '₹ ${session.amount ?? 0}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
      ),
      const Text(
        '$practiceRecipient-க்கு அனுப்பப்பட்டது',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22),
      ),
      const SizedBox(height: 8),
      Text(
        'பயிற்சி இருப்பு: ₹ ${session.balance}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: AppColors.muted),
      ),
      const SizedBox(height: 28),
      _btn('done', 'முடிந்தது', Icons.done_all, color: AppColors.callGreen),
    ],
  );

  Widget _balance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.account_balance, size: 80, color: AppColors.primary),
      const SizedBox(height: 10),
      const Text(
        'கணக்கு இருப்பு',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22),
      ),
      Text(
        '₹ ${session.balance}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 28),
      _btn('done', 'முடிந்தது', Icons.done_all, color: AppColors.callGreen),
    ],
  );
}

class _AmountEntry extends StatefulWidget {
  const _AmountEntry({required this.onAction});
  final void Function(MockAction) onAction;
  @override
  State<_AmountEntry> createState() => _AmountEntryState();
}

class _AmountEntryState extends State<_AmountEntry> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '$practiceRecipient-க்கு',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      _Glow(
        on: true,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () =>
            widget.onAction(EnterAmount(int.tryParse(c.text) ?? 0)),
        child: const Text('அடுத்து'),
      ),
    ],
  );
}

/// A large on-screen keypad, so practice never depends on the phone keyboard.
class _PinEntry extends StatefulWidget {
  const _PinEntry({required this.onAction});
  final void Function(MockAction) onAction;
  @override
  State<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<_PinEntry> {
  int digits = 0;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 32)
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    void add() => setState(() => digits = (digits + 1).clamp(0, 6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'UPI PIN போடுங்கள்',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'இந்த எண்ணை யாரிடமும் சொல்லக் கூடாது',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < digits ? AppColors.ink : Colors.transparent,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, add)]),
        Row(
          children: [
            key(
              '',
              () => setState(() => digits = (digits - 1).clamp(0, 6)),
              icon: Icons.backspace_outlined,
            ),
            key('0', add),
            key('', () {
              widget.onAction(EnterPin(digits));
              setState(() => digits = 0);
            }, icon: Icons.check_circle),
          ],
        ),
      ],
    );
  }
}

/// Yellow glow around the control the narration is pointing at.
class _Glow extends StatelessWidget {
  const _Glow({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.highlight, width: 5),
        boxShadow: [
          BoxShadow(
            color: AppColors.highlight.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: child,
    );
  }
}
