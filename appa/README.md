# Appa App — Phase 1 (minimum lovable version)

A Tamil-first, voice-first Android app for Appa, built from the
[product roadmap](https://claude.ai/artifact/B9DWTfLX9QfvY3wMPEGWxP). It is a bridge to
people, not a replacement for them: every feature ends with Appa talking to someone.

## What is in this build

| Feature | What it does |
|---|---|
| Story of the day | One Tamil question each morning, read aloud. Appa answers by voice. Family hear it and reply with a voice note. |
| Call someone today | Suggests one person a day: whoever he has gone longest without calling. One tap calls; "இன்று வேண்டாம்" (not today) is accepted with no guilt and no second ask. |
| Payment walkthrough with practice mode | A spoken, step-by-step walkthrough of sending money and checking balance on a mock UPI app with a fake ₹5,000 balance. Moves no money and can be repeated without limit. Never grades him. |
| Medicine and sleep | Three daily reminders (morning sleep check-in, medicine, evening wind-down) and a one-tap "how did you sleep?" with a 7-day view. |

Deliberately left out, per the roadmap: the companion chatbot, the family question board,
scam alerts, gamification, and any onboarding longer than two screens.

## Tech stack (all free)

| Part | Choice | Why |
|---|---|---|
| App | Flutter 3.47 (Dart 3.13), Android first | One codebase, strong accessibility, good Tamil rendering |
| Tamil voice out | `flutter_tts` → the phone's own Google TTS engine | Free, offline, no API key |
| Voice recording | `record` (AAC, about 0.5 MB/min) + `just_audio` | Works offline |
| Reminders | `flutter_local_notifications`, scheduled on the phone | No server or push service |
| Calls | `url_launcher` → the phone's dialer | |
| Storage | `shared_preferences` + audio files on the phone | Offline-first; nothing leaves the phone unless sync is on |
| Family sync (optional) | Supabase free tier: Postgres, private storage bucket, anonymous sign-in, row-level security | Family hear stories on their own phones |

No analytics SDKs, no ad SDKs, no trackers, and no LLM in Phase 1. Walkthroughs are
scripted (`lib/logic/walkthrough.dart`), so they are deterministic and never confidently wrong.

## Run it on a phone

Prerequisites on the Mac: [Flutter](https://docs.flutter.dev/get-started/install/macos/mobile-android)
and Android Studio (for the Android SDK). Both are free.

```bash
cd /Users/ragulkts/Highonswift/Appa
flutter pub get
flutter test                 # 29 tests
flutter run                  # with Appa's phone plugged in, USB debugging on
flutter build apk --release  # APK at build/app/outputs/flutter-apk/app-release.apk
```

The release build is signed with the debug key for now. That is fine for installing on
family phones by hand. Create a real signing key before any Play Store upload.

### On Appa's phone, once

1. Open the app and choose **அப்பாவின் போன்** (Appa's phone), then **தொடங்கலாம்**.
2. Allow notifications and the microphone when asked.
3. Tamil voice: **Settings → Accessibility → Text-to-speech → Speech Services by Google →
   Install voice data → தமிழ் (India)**. It's free and works offline. Use the app's
   *குரலைச் சோதி* button to test it.
4. In **குடும்பத்தினருக்கு: அமைப்புகள்** (settings), add his five people from Phase 0
   (name, number, relation) and set the reminder times and medicine name.
5. Sit with him for the first use.

### Family sync (optional, free)

Without sync, everything works on Appa's phone alone, and family can record a reply on
his phone during a visit. To let family listen and reply from their own phones:

1. Create a free project at [supabase.com](https://supabase.com).
2. In the dashboard: **SQL Editor → New query →** paste `supabase/schema.sql` **→ Run**.
3. **Authentication → Sign In / Providers →** turn on **Allow anonymous sign-ins**.
4. **Project Settings → API**: copy the Project URL and the publishable (anon) key.
5. On Appa's phone: settings → paste both → **பகிர்தலைத் தொடங்கு** (start sharing). It shows a
   six-character family code.
6. On each family phone, choose **குடும்பத்தினர் போன்** (family phone) at first launch, then
   in settings paste the same URL and key plus the family code, and tap **சேர்** (join).

Only Appa's stories and the family's replies are shared. Sleep, calls and reminders stay
on his phone. Row-level security limits every row and voice file to one household.

## Code map

```
lib/
  main.dart                 app start, reminder taps, Appa vs family home
  app_state.dart            all state (ChangeNotifier) + offline-first sync logic
  models/models.dart        Contact, Story, StoryReply, SleepEntry, CallEvent, ReminderSettings
  data/story_prompts.dart   30 Tamil story questions (Appa should review them)
  data/local_store.dart     on-device storage
  logic/daily_picker.dart   question of the day, person of the day, sleep window (pure)
  logic/walkthrough.dart    scripted walkthrough engine + Phase 1 scripts (pure)
  services/                 speech, audio, reminders, phone, sync (each with a fake for tests)
  screens/                  setup, home, story, call, walkthrough, routine, settings, family
supabase/schema.sql         tables, RPCs, row-level security, private voice bucket
test/                       unit tests (logic) + widget tests (screens)
```

## Before it reaches Appa

- **Tamil review.** Every script line (story questions, walkthrough narration, buttons) is
  plain spoken Tamil written by the team. Have the Tamil content writer and Appa
  rewrite anything that sounds bookish or patronising.
- **Phase 0 inputs.** Put his three willing TNSTC stories at the top of
  `lib/data/story_prompts.dart`, and his five people in settings.
- **Not yet verified on a device.** The tests run on the Flutter test engine, and the
  Android build has not been run yet. Test recording, playback, Tamil TTS,
  reminders and one-tap calling on his actual phone before handing it over.
- **Exit criteria (from the roadmap).** Used on 10 of 14 days unprompted, at least 5 stories, at least 3
  calls from the nudge, and at least 10 complaints from him.
