import '../data/story_prompts.dart';
import '../models/models.dart';

/// Pure, deterministic daily choices. No randomness, so the same day always
/// shows the same question and the same person, on every phone.

/// The story question for [day]. Questions he has already answered are
/// skipped until every question has been answered once, then the cycle starts
/// again. Stable within a day: answering today's question does not change
/// today's pick ([answeredBeforeToday] should exclude today's answers).
StoryPrompt promptForDay(
  DateTime day, {
  Set<String> answeredBeforeToday = const {},
  List<StoryPrompt> prompts = storyPrompts,
}) {
  assert(prompts.isNotEmpty);
  var pool = prompts.where((p) => !answeredBeforeToday.contains(p.id)).toList();
  if (pool.isEmpty) pool = prompts;
  final dayNumber =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      86400000;
  return pool[dayNumber % pool.length];
}

/// Who to suggest calling on [day].
///
/// The person he has gone longest without calling comes first (never-called
/// first of all, in list order). Anyone he said "not today" to today is
/// skipped. Returns null when the list is empty or he has already called
/// someone, or declined, today: one suggestion a day, no nagging.
Contact? contactForDay(
  DateTime day,
  List<Contact> contacts,
  List<CallEvent> history,
) {
  if (contacts.isEmpty) return null;
  final today = dayKey(day);
  final todays = history.where((e) => e.day == today).toList();
  if (todays.isNotEmpty) return null;

  final ordered = [...contacts]
    ..sort((a, b) {
      final la = a.lastCalled, lb = b.lastCalled;
      if (la == null && lb == null)
        return contacts.indexOf(a).compareTo(contacts.indexOf(b));
      if (la == null) return -1;
      if (lb == null) return 1;
      return la.compareTo(lb);
    });
  return ordered.first;
}

/// Whether today's call nudge is finished (called or "not today").
CallEvent? todaysCallEvent(DateTime day, List<CallEvent> history) {
  final today = dayKey(day);
  for (final e in history.reversed) {
    if (e.day == today) return e;
  }
  return null;
}

/// Morning sleep check-in for [day], if already given.
SleepEntry? sleepEntryFor(DateTime day, List<SleepEntry> entries) {
  final key = dayKey(day);
  for (final e in entries.reversed) {
    if (e.day == key) return e;
  }
  return null;
}

/// Ratings for the last [days] days ending on [today], oldest first; null
/// where he did not answer. Used for the family's simple weekly view.
List<SleepRating?> sleepWindow(
  DateTime today,
  List<SleepEntry> entries, {
  int days = 7,
}) {
  return List.generate(days, (i) {
    final d = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1 - i));
    return sleepEntryFor(d, entries)?.rating;
  });
}
