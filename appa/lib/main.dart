import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'data/local_store.dart';
import 'models/models.dart';
import 'screens/family_screen.dart';
import 'screens/home_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/setup_screen.dart';
import 'services/audio.dart';
import 'services/phone.dart';
import 'services/reminders.dart';
import 'services/speech.dart';
import 'services/sync.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final reminders = DeviceReminders();
  final state = AppState(
    store: await LocalStore.open(),
    speaker: DeviceSpeaker(),
    audio: DeviceVoiceAudio(),
    reminders: reminders,
    phone: DevicePhone(),
    sync: SupabaseFamilySync(),
  );

  await reminders.init(onTap: _openFromReminder);
  if (state.role == DeviceRole.appa) {
    // Re-schedule on every start so a phone restart or app update never
    // silently drops his reminders.
    await reminders.schedule(state.reminderSettings);
  }
  state.speaker.init();
  state.resumeSync();

  runApp(AppaApp(state: state));

  final launched = await reminders.launchPayload();
  if (launched != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openFromReminder(launched),
    );
  }
}

void _openFromReminder(String payload) {
  if (payload == ReminderPayload.checkIn ||
      payload == ReminderPayload.medicine) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const RoutineScreen()),
    );
  }
}

class AppaApp extends StatelessWidget {
  const AppaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'அப்பா',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ta', 'IN'),
        supportedLocales: const [Locale('ta', 'IN'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.isSetUp) return const SetupScreen();
    return s.role == DeviceRole.appa
        ? const HomeScreen()
        : const FamilyHomeScreen();
  }
}
