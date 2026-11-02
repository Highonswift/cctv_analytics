import 'package:appa_app/app_state.dart';
import 'package:appa_app/data/local_store.dart';
import 'package:appa_app/main.dart';
import 'package:appa_app/models/models.dart';
import 'package:appa_app/services/audio.dart';
import 'package:appa_app/services/phone.dart';
import 'package:appa_app/services/reminders.dart';
import 'package:appa_app/services/speech.dart';
import 'package:appa_app/services/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Harness {
  Harness(this.state, this.speaker, this.phone, this.reminders, this.audio);
  final AppState state;
  final SilentSpeaker speaker;
  final FakePhone phone;
  final FakeReminders reminders;
  final FakeVoiceAudio audio;
}

DateTime clock = DateTime(2026, 11, 2, 8, 0);

Future<Harness> makeState({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final speaker = SilentSpeaker();
  final phone = FakePhone();
  final reminders = FakeReminders();
  final audio = FakeVoiceAudio();
  final state = AppState(
    store: await LocalStore.open(),
    speaker: speaker,
    audio: audio,
    reminders: reminders,
    phone: phone,
    sync: NoFamilySync(),
    clock: () => clock,
  );
  return Harness(state, speaker, phone, reminders, audio);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> pumpApp(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppaApp(state: state));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => clock = DateTime(2026, 11, 2, 8, 0));

  group('AppState', () {
    test('setup as Appa schedules the three reminders', () async {
      final h = await makeState();
      await h.state.completeSetup(role: DeviceRole.appa, name: 'அப்பா');
      expect(h.reminders.scheduled, isNotNull);
      expect(h.state.isSetUp, isTrue);
    });

    test(
      'stories persist, and today\'s question stays the same after answering',
      () async {
        final h = await makeState();
        await h.state.completeSetup(role: DeviceRole.appa, name: 'அப்பா');
        final before = h.state.todaysPrompt.id;
        await h.state.saveStory(audioPath: '/fake/a.m4a');
        expect(h.state.todaysPrompt.id, before);
        expect(h.state.answeredToday, isTrue);

        // Next day: a different, unanswered question.
        clock = DateTime(2026, 11, 3, 8);
        expect(h.state.todaysPrompt.id, isNot(before));
        expect(h.state.answeredToday, isFalse);

        // Reload from storage.
        final again = AppState(
          store: h.state.store,
          speaker: SilentSpeaker(),
          audio: FakeVoiceAudio(),
          reminders: FakeReminders(),
          phone: FakePhone(),
          sync: NoFamilySync(),
          clock: () => clock,
        );
        expect(again.stories.length, 1);
      },
    );

    test('local family reply is unheard until played', () async {
      final h = await makeState();
      final story = await h.state.saveStory(audioPath: '/fake/a.m4a');
      await h.state.addLocalReply(
        storyId: story.id,
        author: 'ராகுல்',
        audioPath: '/fake/r.m4a',
      );
      expect(h.state.unheardReplies, 1);
      await h.state.markReplyHeard(
        story.id,
        h.state.stories.first.replies.first.id,
      );
      expect(h.state.unheardReplies, 0);
    });

    test('sleep rating replaces same-day answer', () async {
      final h = await makeState();
      await h.state.rateSleep(SleepRating.bad);
      await h.state.rateSleep(SleepRating.good);
      expect(h.state.sleepEntries.length, 1);
      expect(h.state.todaysSleep!.rating, SleepRating.good);
    });
  });

  group('screens', () {
    testWidgets('first run: two-screen setup lands on Appa home', (
      tester,
    ) async {
      final h = await makeState();
      await pumpApp(tester, h.state);
      expect(find.text('இந்த போன் யாருடையது?'), findsOneWidget);
      await tapText(tester, 'அப்பாவின் போன்');
      await tapText(tester, 'தொடங்கலாம்');
      expect(find.textContaining('காலை வணக்கம், அப்பா'), findsOneWidget);
      expect(find.text('இன்றைய கதை'), findsOneWidget);
      expect(find.text('இன்று யாரிடம் பேசலாம்'), findsOneWidget);
      expect(find.text('பணம் அனுப்பப் பழகுவோம்'), findsOneWidget);
      expect(find.text('தூக்கமும் மாத்திரையும்'), findsOneWidget);
    });

    testWidgets('morning sleep check-in is one tap on the home screen', (
      tester,
    ) async {
      final h = await makeState(
        prefs: {'role': 'appa', 'displayName': 'அப்பா'},
      );
      await pumpApp(tester, h.state);
      expect(find.text('நேற்று இரவு தூக்கம் எப்படி?'), findsOneWidget);
      await tapText(tester, 'நன்றாகத் தூங்கினேன்');
      expect(h.state.todaysSleep!.rating, SleepRating.good);
      // Answered: the card leaves the home screen.
      expect(find.text('நேற்று இரவு தூக்கம் எப்படி?'), findsNothing);
    });

    testWidgets('call someone today: call, then no more nudging today', (
      tester,
    ) async {
      final h = await makeState(
        prefs: {'role': 'appa', 'displayName': 'அப்பா'},
      );
      await h.state.saveContact(
        Contact(
          id: 'm',
          name: 'முருகன்',
          phone: '98400 12345',
          relation: 'டிப்போ நண்பர்',
        ),
      );
      await pumpApp(tester, h.state);
      await tapText(tester, 'இன்று யாரிடம் பேசலாம்');
      expect(h.speaker.spoken.last, contains('முருகன்'));
      await tapText(tester, 'முருகன்-ஐ அழை');
      expect(h.phone.dialled, ['98400 12345']);
      expect(
        find.textContaining('இன்று முருகன்-உடன் பேசினீர்கள்'),
        findsWidgets,
      );
    });

    testWidgets('"not today" is accepted quietly', (tester) async {
      final h = await makeState(
        prefs: {'role': 'appa', 'displayName': 'அப்பா'},
      );
      await h.state.saveContact(Contact(id: 'm', name: 'முருகன்', phone: '1'));
      await pumpApp(tester, h.state);
      await tapText(tester, 'இன்று யாரிடம் பேசலாம்');
      await tapText(tester, 'இன்று வேண்டாம்');
      expect(h.phone.dialled, isEmpty);
      expect(find.text('சரி. நாளை பார்க்கலாம்.'), findsOneWidget);
    });

    testWidgets('practice payment walkthrough runs end to end', (tester) async {
      final h = await makeState(
        prefs: {'role': 'appa', 'displayName': 'அப்பா'},
      );
      await pumpApp(tester, h.state);
      await tapText(tester, 'பணம் அனுப்பப் பழகுவோம்');
      await tapText(tester, 'பணம் அனுப்புவது');
      expect(find.text('பயிற்சி — உண்மையான பணம் இல்லை'), findsOneWidget);

      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tap(find.text('தொடங்கு'));
      // A different button: gentle pointer, not "wrong".
      await tap(find.text('QR ஸ்கேன்'));
      expect(find.textContaining('மஞ்சள் நிறத்தில்'), findsWidgets);
      await tap(find.text('பணம் அனுப்பு'));
      await tap(find.text('முருகன்'));
      await tester.enterText(find.byType(TextField), '300');
      await tap(find.text('அடுத்து'));
      expect(find.text('₹ 300'), findsOneWidget);
      await tap(find.text('அனுப்பு'));
      for (final d in ['1', '2', '3', '4']) {
        await tap(find.text(d));
      }
      await tap(find.byIcon(Icons.check_circle));
      expect(find.textContaining('4700'), findsWidgets);
      await tap(find.text('முடிந்தது'));
      expect(h.state.completedWalkthroughs, contains('upi-send'));
      expect(find.text('மீண்டும் செய்து பார்'), findsOneWidget);
    });

    testWidgets('story screen speaks the question and saves a recording', (
      tester,
    ) async {
      final h = await makeState(
        prefs: {'role': 'appa', 'displayName': 'அப்பா'},
      );
      await pumpApp(tester, h.state);
      await tapText(tester, 'இன்றைய கதை');
      expect(h.speaker.spoken.last, contains(h.state.todaysPrompt.tamil));
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();
      await tapText(tester, 'கதையைச் சேமி');
      expect(h.state.stories.length, 1);
      expect(find.textContaining('உங்கள் கதை சேமிக்கப்பட்டது'), findsOneWidget);
    });

    testWidgets('family phone without sync explains how to connect', (
      tester,
    ) async {
      final h = await makeState(
        prefs: {'role': 'family', 'displayName': 'ராகுல்'},
      );
      await pumpApp(tester, h.state);
      expect(find.text('அப்பாவின் கதைகள்'), findsOneWidget);
      expect(find.textContaining('குடும்பக் குறியீடும்'), findsOneWidget);
    });

    testWidgets('settings: add a contact', (tester) async {
      final h = await makeState(
        prefs: {'role': 'appa', 'displayName': 'அப்பா'},
      );
      await pumpApp(tester, h.state);
      await tester.ensureVisible(find.text('குடும்பத்தினருக்கு: அமைப்புகள்'));
      await tapText(tester, 'குடும்பத்தினருக்கு: அமைப்புகள்');
      await tapText(tester, 'ஒருவரைச் சேர்');
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'கணேசன்');
      await tester.enterText(fields.at(1), '9840012345');
      await tapText(tester, 'சேமி');
      expect(h.state.contacts.single.name, 'கணேசன்');
    });
  });
}
