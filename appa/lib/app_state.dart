import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'data/local_store.dart';
import 'data/story_prompts.dart';
import 'logic/daily_picker.dart';
import 'models/models.dart';
import 'services/audio.dart';
import 'services/phone.dart';
import 'services/reminders.dart';
import 'services/speech.dart';
import 'services/sync.dart';

/// The whole app's state. One ChangeNotifier, deliberately simple: one user,
/// one phone, a handful of lists.
class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.speaker,
    required this.audio,
    required this.reminders,
    required this.phone,
    required this.sync,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _load();
  }

  final LocalStore store;
  final Speaker speaker;
  final VoiceAudio audio;
  final Reminders reminders;
  final Phone phone;
  final FamilySync sync;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  DateTime get now => _clock();

  late DeviceRole? role;
  late String displayName;
  late List<Contact> contacts;
  late List<CallEvent> callEvents;
  late List<Story> stories;
  late List<SleepEntry> sleepEntries;
  late ReminderSettings reminderSettings;
  late Set<String> completedWalkthroughs;

  /// Last sync problem, shown quietly in settings, never to Appa.
  String? syncError;
  bool syncing = false;

  void _load() {
    role = store.role;
    displayName = store.displayName;
    contacts = store.contacts;
    callEvents = store.callEvents;
    stories = store.stories..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    sleepEntries = store.sleepEntries;
    reminderSettings = store.reminders;
    completedWalkthroughs = store.completedWalkthroughs;
  }

  // ---------------------------------------------------------------- setup

  bool get isSetUp => role != null;

  Future<void> completeSetup({
    required DeviceRole role,
    required String name,
  }) async {
    this.role = role;
    displayName = name.trim();
    await store.setRole(role);
    await store.setDisplayName(displayName);
    if (role == DeviceRole.appa) await reminders.schedule(reminderSettings);
    notifyListeners();
  }

  // ---------------------------------------------------------------- stories

  /// Today's question. Stable for the whole day, even after he answers it.
  StoryPrompt get todaysPrompt {
    final today = dayKey(now);
    final answeredBefore = stories
        .where((s) => dayKey(s.createdAt) != today)
        .map((s) => s.promptId)
        .toSet();
    return promptForDay(now, answeredBeforeToday: answeredBefore);
  }

  bool get answeredToday =>
      stories.any((s) => dayKey(s.createdAt) == dayKey(now));

  int get unheardReplies => stories.fold(0, (n, s) => n + s.unheardReplies);

  Future<Story> saveStory({
    required String audioPath,
    StoryPrompt? prompt,
  }) async {
    final p = prompt ?? todaysPrompt;
    final story = Story(
      id: _uuid.v4(),
      promptId: p.id,
      promptText: p.tamil,
      createdAt: now,
      localAudioPath: audioPath,
    );
    stories = [story, ...stories];
    await store.saveStories(stories);
    notifyListeners();
    await pushStories();
    return story;
  }

  Future<void> deleteStory(String id) async {
    stories = stories.where((s) => s.id != id).toList();
    await store.saveStories(stories);
    notifyListeners();
  }

  /// A reply recorded on this same phone (for example Ragul sitting with him
  /// on a visit). Works without sync.
  Future<void> addLocalReply({
    required String storyId,
    required String author,
    required String audioPath,
  }) async {
    stories = [
      for (final s in stories)
        if (s.id == storyId)
          s.copyWith(
            replies: [
              ...s.replies,
              StoryReply(
                id: _uuid.v4(),
                authorName: author,
                createdAt: now,
                localAudioPath: audioPath,
              ),
            ],
          )
        else
          s,
    ];
    await store.saveStories(stories);
    notifyListeners();
  }

  Future<void> markReplyHeard(String storyId, String replyId) async {
    stories = [
      for (final s in stories)
        if (s.id == storyId)
          s.copyWith(
            replies: [
              for (final r in s.replies)
                r.id == replyId ? r.copyWith(listened: true) : r,
            ],
          )
        else
          s,
    ];
    await store.saveStories(stories);
    notifyListeners();
    if (sync.connected) {
      try {
        await sync.markReplyHeard(replyId);
      } catch (e) {
        syncError = '$e';
      }
    }
  }

  // ---------------------------------------------------------------- calls

  Contact? get todaysContact => contactForDay(now, contacts, callEvents);
  CallEvent? get todaysCall => todaysCallEvent(now, callEvents);

  Contact? contactById(String id) {
    for (final c in contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> callContact(Contact c) async {
    final ok = await phone.call(c.phone);
    if (!ok) return;
    final t = now;
    callEvents = [
      ...callEvents,
      CallEvent(
        day: dayKey(t),
        contactId: c.id,
        outcome: CallOutcome.called,
        at: t,
      ),
    ];
    contacts = [
      for (final x in contacts) x.id == c.id ? x.copyWith(lastCalled: t) : x,
    ];
    await store.saveCallEvents(callEvents);
    await store.saveContacts(contacts);
    notifyListeners();
  }

  /// "Not today" — accepted without question, no guilt, no re-asking today.
  Future<void> notToday(Contact c) async {
    final t = now;
    callEvents = [
      ...callEvents,
      CallEvent(
        day: dayKey(t),
        contactId: c.id,
        outcome: CallOutcome.notToday,
        at: t,
      ),
    ];
    await store.saveCallEvents(callEvents);
    notifyListeners();
  }

  Future<void> saveContact(Contact c) async {
    final exists = contacts.any((x) => x.id == c.id);
    contacts = exists
        ? [for (final x in contacts) x.id == c.id ? c : x]
        : [...contacts, c];
    await store.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> removeContact(String id) async {
    contacts = contacts.where((c) => c.id != id).toList();
    await store.saveContacts(contacts);
    notifyListeners();
  }

  String newId() => _uuid.v4();

  // ---------------------------------------------------------------- sleep

  SleepEntry? get todaysSleep => sleepEntryFor(now, sleepEntries);

  Future<void> rateSleep(SleepRating r) async {
    final t = now;
    final key = dayKey(t);
    sleepEntries = [
      ...sleepEntries.where((e) => e.day != key),
      SleepEntry(day: key, rating: r, recordedAt: t),
    ];
    await store.saveSleepEntries(sleepEntries);
    notifyListeners();
  }

  List<SleepRating?> get lastWeekSleep => sleepWindow(now, sleepEntries);

  // ---------------------------------------------------------------- reminders

  Future<void> updateReminders(ReminderSettings s) async {
    reminderSettings = s;
    await store.saveReminders(s);
    await reminders.schedule(s);
    notifyListeners();
  }

  // ---------------------------------------------------------------- walkthroughs

  /// Acknowledged once, quietly. Returns true the first time only.
  Future<bool> markWalkthroughDone(String id) async {
    if (completedWalkthroughs.contains(id)) return false;
    completedWalkthroughs = {...completedWalkthroughs, id};
    await store.saveCompletedWalkthroughs(completedWalkthroughs);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------- family sync

  bool get syncConfigured => store.syncUrl != null && store.syncKey != null;

  /// Reconnect on start if sync was set up before. Never blocks the app.
  Future<void> resumeSync() async {
    final url = store.syncUrl, key = store.syncKey, code = store.householdCode;
    if (url == null || key == null || code == null) return;
    try {
      await sync.connect(url: url, key: key);
      await sync.resume(householdCode: code);
      syncError = null;
      if (role == DeviceRole.appa) await pullReplies();
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  /// Set up sync from settings. Appa's phone creates the household; a family
  /// phone joins with [joinCode].
  Future<String?> setUpSync({
    required String url,
    required String key,
    String? joinCode,
  }) async {
    syncing = true;
    notifyListeners();
    try {
      await sync.connect(url: url.trim(), key: key.trim());
      String code;
      if (role == DeviceRole.appa) {
        code = await sync.createHousehold(displayName: displayName);
      } else {
        if (joinCode == null || joinCode.trim().isEmpty)
          throw ArgumentError('Join code needed');
        await sync.joinHousehold(code: joinCode, displayName: displayName);
        code = joinCode.trim().toUpperCase();
      }
      await store.saveSync(
        url: url.trim(),
        key: key.trim(),
        householdCode: code,
      );
      syncError = null;
      if (role == DeviceRole.appa) await pushStories();
      return code;
    } catch (e) {
      syncError = '$e';
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Upload stories not yet shared. Called after each recording; failures
  /// are retried next time (offline-first).
  Future<void> pushStories() async {
    if (!sync.connected || role != DeviceRole.appa) return;
    var changed = false;
    final updated = <Story>[];
    for (final s in stories) {
      if (!s.synced && s.localAudioPath != null) {
        try {
          final path = await sync.uploadStory(s);
          updated.add(s.copyWith(remoteAudioPath: path));
          changed = true;
          continue;
        } catch (e) {
          syncError = '$e';
        }
      }
      updated.add(s);
    }
    if (changed) {
      stories = updated;
      await store.saveStories(stories);
      notifyListeners();
    }
  }

  /// Fetch family voice replies and keep a local copy so they play offline.
  Future<void> pullReplies() async {
    if (!sync.connected || role != DeviceRole.appa) return;
    try {
      await pushStories();
      final remote = await sync.fetchReplies();
      var next = stories;
      for (final r in remote) {
        final idx = next.indexWhere((s) => s.id == r.storyId);
        if (idx < 0) continue;
        final s = next[idx];
        if (s.replies.any((x) => x.id == r.id)) continue;
        final local = await audio.filePath('reply-${r.id}.m4a');
        await sync.downloadToFile(r.audioPath, local);
        final reply = StoryReply(
          id: r.id,
          authorName: r.authorName,
          createdAt: r.createdAt,
          localAudioPath: local,
          remoteAudioPath: r.audioPath,
          listened: r.listened,
        );
        next = [...next]..[idx] = s.copyWith(replies: [...s.replies, reply]);
      }
      stories = next;
      await store.saveStories(stories);
      syncError = null;
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  // Family side -----------------------------------------------------------

  List<RemoteStory> familyStories = [];

  Set<String> get seenFamilyStories => store.seenFamilyStories;

  Future<void> loadFamilyStories() async {
    if (!sync.connected) return;
    syncing = true;
    notifyListeners();
    try {
      familyStories = await sync.fetchStories();
      syncError = null;
    } catch (e) {
      syncError = '$e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> markFamilyStorySeen(String id) async {
    await store.saveSeenFamilyStories({...store.seenFamilyStories, id});
    notifyListeners();
  }

  Future<bool> sendFamilyReply({
    required String storyId,
    required String audioPath,
  }) async {
    try {
      await sync.uploadReply(
        storyId: storyId,
        localPath: audioPath,
        authorName: displayName,
      );
      await loadFamilyStories();
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }
}
