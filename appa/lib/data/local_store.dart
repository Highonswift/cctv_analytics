import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// On-device storage. Everything works with no network: stories, the daily
/// plan of reminders, the call nudge and the sleep log all live here first.
/// Small records are JSON in SharedPreferences; audio files live in the app's
/// documents directory and only their paths are stored here.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  static const _kRole = 'role';
  static const _kName = 'displayName';
  static const _kContacts = 'contacts';
  static const _kCalls = 'callEvents';
  static const _kStories = 'stories';
  static const _kSleep = 'sleepEntries';
  static const _kReminders = 'reminders';
  static const _kDoneWalks = 'completedWalkthroughs';
  static const _kSyncUrl = 'syncUrl';
  static const _kSyncKey = 'syncKey';
  static const _kHousehold = 'householdCode';
  static const _kSeenFamilyStories = 'seenFamilyStories';

  DeviceRole? get role {
    final r = _prefs.getString(_kRole);
    return r == null ? null : DeviceRole.values.byName(r);
  }

  Future<void> setRole(DeviceRole r) => _prefs.setString(_kRole, r.name);

  String get displayName => _prefs.getString(_kName) ?? '';
  Future<void> setDisplayName(String n) => _prefs.setString(_kName, n);

  List<T> _list<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> items) =>
      _prefs.setString(key, jsonEncode(items));

  List<Contact> get contacts => _list(_kContacts, Contact.fromJson);
  Future<void> saveContacts(List<Contact> c) =>
      _saveList(_kContacts, c.map((e) => e.toJson()).toList());

  List<CallEvent> get callEvents => _list(_kCalls, CallEvent.fromJson);
  Future<void> saveCallEvents(List<CallEvent> c) =>
      _saveList(_kCalls, c.map((e) => e.toJson()).toList());

  List<Story> get stories => _list(_kStories, Story.fromJson);
  Future<void> saveStories(List<Story> s) =>
      _saveList(_kStories, s.map((e) => e.toJson()).toList());

  List<SleepEntry> get sleepEntries => _list(_kSleep, SleepEntry.fromJson);
  Future<void> saveSleepEntries(List<SleepEntry> s) =>
      _saveList(_kSleep, s.map((e) => e.toJson()).toList());

  ReminderSettings get reminders {
    final raw = _prefs.getString(_kReminders);
    if (raw == null) return const ReminderSettings();
    try {
      return ReminderSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const ReminderSettings();
    }
  }

  Future<void> saveReminders(ReminderSettings r) =>
      _prefs.setString(_kReminders, jsonEncode(r.toJson()));

  Set<String> get completedWalkthroughs =>
      (_prefs.getStringList(_kDoneWalks) ?? []).toSet();
  Future<void> saveCompletedWalkthroughs(Set<String> ids) =>
      _prefs.setStringList(_kDoneWalks, ids.toList());

  /// Story ids a family phone has already opened (to mark new ones).
  Set<String> get seenFamilyStories =>
      (_prefs.getStringList(_kSeenFamilyStories) ?? []).toSet();
  Future<void> saveSeenFamilyStories(Set<String> ids) =>
      _prefs.setStringList(_kSeenFamilyStories, ids.toList());

  /// Optional family sync (Supabase free tier). All three must be set.
  String? get syncUrl => _prefs.getString(_kSyncUrl);
  String? get syncKey => _prefs.getString(_kSyncKey);
  String? get householdCode => _prefs.getString(_kHousehold);

  Future<void> saveSync({
    required String url,
    required String key,
    String? householdCode,
  }) async {
    await _prefs.setString(_kSyncUrl, url);
    await _prefs.setString(_kSyncKey, key);
    if (householdCode != null) {
      await _prefs.setString(_kHousehold, householdCode);
    }
  }

  Future<void> saveHouseholdCode(String code) =>
      _prefs.setString(_kHousehold, code);

  Future<void> clearSync() async {
    await _prefs.remove(_kSyncUrl);
    await _prefs.remove(_kSyncKey);
    await _prefs.remove(_kHousehold);
  }
}
