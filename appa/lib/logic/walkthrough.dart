/// Scripted walkthrough engine.
///
/// Walkthroughs are data, not LLM output, so they are deterministic and never
/// confidently wrong (roadmap: "Walkthroughs: scripted step engine"). Each
/// step names the mock screen to show, what to say aloud, and the one action
/// that moves forward. Any other tap gets a gentle pointer to the right
/// button, never a "wrong".
library;

/// The mock screens of the practice payment app.
enum MockScreen {
  intro,
  home,
  contacts,
  amount,
  confirm,
  pin,
  success,
  balance,
}

/// What the learner did on a mock screen.
sealed class MockAction {
  const MockAction();
}

/// Tapped the control with this id.
class Tap extends MockAction {
  const Tap(this.target);
  final String target;
}

/// Typed an amount (rupees) and pressed continue.
class EnterAmount extends MockAction {
  const EnterAmount(this.rupees);
  final int rupees;
}

/// Entered a PIN of this many digits and pressed the tick.
class EnterPin extends MockAction {
  const EnterPin(this.digits);
  final int digits;
}

/// One step of a walkthrough.
class WalkStep {
  const WalkStep({
    required this.screen,
    required this.say,
    required this.expects,
    this.target,
    this.hint,
  });

  final MockScreen screen;

  /// Spoken aloud (Tamil) when the step starts, and shown in large text.
  final String say;

  /// Which kind of action moves on.
  final Type expects;

  /// For [Tap] steps: the control id that must be tapped. It is highlighted.
  final String? target;

  /// Said when he does something else. Points at the right control; never
  /// says he was wrong.
  final String? hint;
}

class Walkthrough {
  const Walkthrough({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
  });
  final String id;
  final String title;
  final String summary;
  final List<WalkStep> steps;
}

/// Name of the pretend person in the practice contact list.
const practiceRecipient = 'முருகன்';
const practiceStartBalance = 5000;

/// Result of handling an action.
class StepResult {
  const StepResult({required this.advanced, this.message});
  final bool advanced;

  /// Text to speak: the next step's narration, or a hint.
  final String? message;
}

/// Runs one walkthrough over a fake balance. Moves no money: there is no
/// network or payment code anywhere in this module.
class WalkthroughSession {
  WalkthroughSession(this.walkthrough, {this.balance = practiceStartBalance});

  final Walkthrough walkthrough;
  int balance;
  int index = 0;
  int? amount;
  int pinDigits = 0;

  WalkStep get step => walkthrough.steps[index];
  bool _doneTapped = false;

  /// True once the last step's action has been done.
  bool get completed => _doneTapped;

  /// Handle [action] on the current step.
  StepResult handle(MockAction action) {
    final s = step;
    final matches = switch (action) {
      Tap(:final target) => s.expects == Tap && target == s.target,
      EnterAmount(:final rupees) => s.expects == EnterAmount && rupees > 0,
      EnterPin(:final digits) =>
        s.expects == EnterPin && (digits == 4 || digits == 6),
    };

    if (!matches) {
      if (action is EnterAmount && s.expects == EnterAmount) {
        return const StepResult(
          advanced: false,
          message: 'ஒரு தொகையை எண்களில் போடுங்கள். உதாரணமாக 100.',
        );
      }
      if (action is EnterPin && s.expects == EnterPin) {
        return const StepResult(
          advanced: false,
          message: 'PIN நான்கு அல்லது ஆறு எண்கள். இது பயிற்சி, எந்த எண்ணும் போடலாம்.',
        );
      }
      return StepResult(
        advanced: false,
        message: s.hint == null ? null : _fill(s.hint!),
      );
    }

    if (action is EnterAmount) {
      if (action.rupees > balance) {
        return const StepResult(
          advanced: false,
          message: 'இருப்பை விடக் குறைவான தொகை போடுங்கள்.',
        );
      }
      amount = action.rupees;
    }
    if (action is EnterPin) {
      pinDigits = action.digits;
      // The pretend payment "happens" only in this practice object.
      if (walkthrough.steps.any((st) => st.screen == MockScreen.amount) &&
          amount != null) {
        balance -= amount!;
      }
    }

    if (index == walkthrough.steps.length - 1) {
      _doneTapped = true;
      return const StepResult(advanced: true);
    }
    index++;
    return StepResult(advanced: true, message: narration(step));
  }

  /// The narration for [s], with the practice amounts filled in.
  String narration(WalkStep s) => _fill(s.say);

  String _fill(String text) => text
      .replaceAll('{amount}', '${amount ?? 0}')
      .replaceAll('{balance}', '$balance')
      .replaceAll('{name}', practiceRecipient);

  /// Start again from the first step, with the balance reset. Unlimited.
  void restart() {
    index = 0;
    amount = null;
    pinDigits = 0;
    balance = practiceStartBalance;
    _doneTapped = false;
  }
}

/// Phase 1 walkthroughs. Scripts in plain spoken Tamil; the Tamil content
/// writer and Appa should review every line before it ships to him.
const sendMoneyWalkthrough = Walkthrough(
  id: 'upi-send',
  title: 'பணம் அனுப்புவது',
  summary: 'GPay போன்ற UPI ஆப்பில் ஒருவருக்குப் பணம் அனுப்பும் முறை',
  steps: [
    WalkStep(
      screen: MockScreen.intro,
      say: 'இது பயிற்சி மட்டும். உண்மையான பணம் எங்கும் போகாது. எத்தனை தடவை வேண்டுமானாலும் செய்து பார்க்கலாம். தொடங்க, "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
      expects: Tap,
      target: 'start',
      hint: 'கீழே உள்ள "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.home,
      say: 'இது ஆப்பின் முதல் பக்கம். GPay-யிலும் இதே மாதிரி இருக்கும். ஒருவருக்குப் பணம் அனுப்ப, "பணம் அனுப்பு" என்ற பொத்தானை அழுத்துங்கள்.',
      expects: Tap,
      target: 'pay',
      hint: 'மஞ்சள் நிறத்தில் மின்னும் "பணம் அனுப்பு" பொத்தானை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.contacts,
      say: 'இப்போது யாருக்கு அனுப்ப வேண்டுமோ, அவர் பெயரை அழுத்துங்கள். இங்கே {name} பெயரை அழுத்துங்கள்.',
      expects: Tap,
      target: 'contact',
      hint: '{name} என்ற பெயரை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.amount,
      say: 'எவ்வளவு பணம் அனுப்ப வேண்டும் என்று எண்களில் போடுங்கள். பிறகு "அடுத்து" அழுத்துங்கள்.',
      expects: EnterAmount,
      hint: 'ஒரு தொகையை எண்களில் போட்டு "அடுத்து" அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.confirm,
      say: 'அனுப்பும் முன் இரண்டு விஷயம் பாருங்கள்: பெயர் {name} தானா, தொகை {amount} ரூபாய் தானா. சரி என்றால், "அனுப்பு" அழுத்துங்கள்.',
      expects: Tap,
      target: 'send',
      hint: 'பெயரும் தொகையும் சரியா என்று பார்த்து, "அனுப்பு" அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.pin,
      say: 'இப்போது UPI PIN கேட்கும். இது உங்கள் ரகசிய எண். வங்கியிலிருந்து பேசுவதாகச் சொன்னாலும், யாரிடமும் இதைச் சொல்லக் கூடாது. இது பயிற்சி, அதனால் எந்த நான்கு எண்ணும் போடலாம்.',
      expects: EnterPin,
      hint: 'நான்கு எண்கள் போட்டு, சரி குறியை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.success,
      say: '{amount} ரூபாய் {name}-க்குப் போய்விட்டது என்று காட்டுகிறது. பச்சை சரி குறி வந்தால் பணம் போய்விட்டது. பயிற்சி இருப்பு இப்போது {balance} ரூபாய். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
      expects: Tap,
      target: 'done',
      hint: '"முடிந்தது" பொத்தானை அழுத்துங்கள்.',
    ),
  ],
);

const checkBalanceWalkthrough = Walkthrough(
  id: 'upi-balance',
  title: 'இருப்பு பார்ப்பது',
  summary: 'வங்கிக் கணக்கில் எவ்வளவு பணம் இருக்கிறது என்று பார்க்கும் முறை',
  steps: [
    WalkStep(
      screen: MockScreen.intro,
      say: 'இது பயிற்சி மட்டும். வங்கிக் கணக்கில் எவ்வளவு பணம் இருக்கிறது என்று பார்க்கக் கற்றுக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
      expects: Tap,
      target: 'start',
      hint: 'கீழே உள்ள "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.home,
      say: 'முதல் பக்கத்தில் "இருப்பு பார்" என்ற பொத்தானை அழுத்துங்கள்.',
      expects: Tap,
      target: 'balance',
      hint: 'மஞ்சள் நிறத்தில் மின்னும் "இருப்பு பார்" பொத்தானை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.pin,
      say: 'இருப்பு பார்க்கவும் UPI PIN கேட்கும். இதை யாரிடமும் சொல்லக் கூடாது. பயிற்சிக்கு எந்த நான்கு எண்ணும் போடுங்கள்.',
      expects: EnterPin,
      hint: 'நான்கு எண்கள் போட்டு, சரி குறியை அழுத்துங்கள்.',
    ),
    WalkStep(
      screen: MockScreen.balance,
      say: 'உங்கள் பயிற்சிக் கணக்கில் {balance} ரூபாய் இருக்கிறது என்று காட்டுகிறது. முடிக்க "முடிந்தது" அழுத்துங்கள்.',
      expects: Tap,
      target: 'done',
      hint: '"முடிந்தது" பொத்தானை அழுத்துங்கள்.',
    ),
  ],
);

const phaseOneWalkthroughs = [sendMoneyWalkthrough, checkBalanceWalkthrough];
