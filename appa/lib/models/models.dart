/// Plain data models. Everything is JSON-serialisable so it can live in
/// on-device storage and, optionally, be mirrored to Supabase.
library;

/// Calendar day key (local time), e.g. "2026-11-02".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A person Appa might call. Added by family in settings, by name.
class Contact {
  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = '',
    this.lastCalled,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
  final DateTime? lastCalled;

  Contact copyWith({
    String? name,
    String? phone,
    String? relation,
    DateTime? lastCalled,
  }) => Contact(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    relation: relation ?? this.relation,
    lastCalled: lastCalled ?? this.lastCalled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relation': relation,
    'lastCalled': lastCalled?.toIso8601String(),
  };

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    relation: j['relation'] as String? ?? '',
    lastCalled: j['lastCalled'] == null
        ? null
        : DateTime.parse(j['lastCalled'] as String),
  );
}

/// A voice reply from a family member to one of Appa's stories.
class StoryReply {
  StoryReply({
    required this.id,
    required this.authorName,
    required this.createdAt,
    this.localAudioPath,
    this.remoteAudioPath,
    this.listened = false,
  });

  final String id;
  final String authorName;
  final DateTime createdAt;
  final String? localAudioPath;
  final String? remoteAudioPath;
  final bool listened;

  StoryReply copyWith({
    String? localAudioPath,
    String? remoteAudioPath,
    bool? listened,
  }) => StoryReply(
    id: id,
    authorName: authorName,
    createdAt: createdAt,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    remoteAudioPath: remoteAudioPath ?? this.remoteAudioPath,
    listened: listened ?? this.listened,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'createdAt': createdAt.toIso8601String(),
    'localAudioPath': localAudioPath,
    'remoteAudioPath': remoteAudioPath,
    'listened': listened,
  };

  factory StoryReply.fromJson(Map<String, dynamic> j) => StoryReply(
    id: j['id'] as String,
    authorName: j['authorName'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    localAudioPath: j['localAudioPath'] as String?,
    remoteAudioPath: j['remoteAudioPath'] as String?,
    listened: j['listened'] as bool? ?? false,
  );
}

/// One recorded answer to the story-of-the-day question.
class Story {
  Story({
    required this.id,
    required this.promptId,
    required this.promptText,
    required this.createdAt,
    this.localAudioPath,
    this.remoteAudioPath,
    this.replies = const [],
  });

  final String id;
  final String promptId;
  final String promptText;
  final DateTime createdAt;
  final String? localAudioPath;
  final String? remoteAudioPath;
  final List<StoryReply> replies;

  bool get synced => remoteAudioPath != null;
  int get unheardReplies => replies.where((r) => !r.listened).length;

  Story copyWith({
    String? remoteAudioPath,
    String? localAudioPath,
    List<StoryReply>? replies,
  }) => Story(
    id: id,
    promptId: promptId,
    promptText: promptText,
    createdAt: createdAt,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    remoteAudioPath: remoteAudioPath ?? this.remoteAudioPath,
    replies: replies ?? this.replies,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'promptId': promptId,
    'promptText': promptText,
    'createdAt': createdAt.toIso8601String(),
    'localAudioPath': localAudioPath,
    'remoteAudioPath': remoteAudioPath,
    'replies': replies.map((r) => r.toJson()).toList(),
  };

  factory Story.fromJson(Map<String, dynamic> j) => Story(
    id: j['id'] as String,
    promptId: j['promptId'] as String? ?? '',
    promptText: j['promptText'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    localAudioPath: j['localAudioPath'] as String?,
    remoteAudioPath: j['remoteAudioPath'] as String?,
    replies: ((j['replies'] as List?) ?? [])
        .map((e) => StoryReply.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

enum SleepRating { good, okay, bad }

/// The one-tap morning answer to "how did you sleep?".
class SleepEntry {
  SleepEntry({
    required this.day,
    required this.rating,
    required this.recordedAt,
  });

  final String day; // dayKey of the morning it was recorded
  final SleepRating rating;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'day': day,
    'rating': rating.name,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory SleepEntry.fromJson(Map<String, dynamic> j) => SleepEntry(
    day: j['day'] as String,
    rating: SleepRating.values.byName(j['rating'] as String),
    recordedAt: DateTime.parse(j['recordedAt'] as String),
  );
}

/// What happened with the daily call nudge.
enum CallOutcome { called, notToday }

class CallEvent {
  CallEvent({
    required this.day,
    required this.contactId,
    required this.outcome,
    required this.at,
  });

  final String day;
  final String contactId;
  final CallOutcome outcome;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'day': day,
    'contactId': contactId,
    'outcome': outcome.name,
    'at': at.toIso8601String(),
  };

  factory CallEvent.fromJson(Map<String, dynamic> j) => CallEvent(
    day: j['day'] as String,
    contactId: j['contactId'] as String,
    outcome: CallOutcome.values.byName(j['outcome'] as String),
    at: DateTime.parse(j['at'] as String),
  );
}

/// A time of day, stored as minutes since midnight.
class TimeOfDayMinutes {
  const TimeOfDayMinutes(this.hour, this.minute);
  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;
  factory TimeOfDayMinutes.fromTotal(int m) =>
      TimeOfDayMinutes((m ~/ 60) % 24, m % 60);

  /// Tamil 12-hour label, e.g. "காலை 7:00", "இரவு 9:30".
  String get label {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12
        ? 'காலை'
        : hour < 16
        ? 'மதியம்'
        : hour < 19
        ? 'மாலை'
        : 'இரவு';
    return '$period $h12:${minute.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayMinutes && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => totalMinutes;
}

/// The three daily reminders. The roadmap caps notifications at three a day,
/// so this is the complete set: nothing else in the app may notify.
class ReminderSettings {
  const ReminderSettings({
    this.morningCheckIn = const TimeOfDayMinutes(7, 0),
    this.medicine = const TimeOfDayMinutes(8, 30),
    this.windDown = const TimeOfDayMinutes(21, 0),
    this.medicineName = '',
    this.enabled = true,
  });

  final TimeOfDayMinutes morningCheckIn;
  final TimeOfDayMinutes medicine;
  final TimeOfDayMinutes windDown;
  final String medicineName;
  final bool enabled;

  ReminderSettings copyWith({
    TimeOfDayMinutes? morningCheckIn,
    TimeOfDayMinutes? medicine,
    TimeOfDayMinutes? windDown,
    String? medicineName,
    bool? enabled,
  }) => ReminderSettings(
    morningCheckIn: morningCheckIn ?? this.morningCheckIn,
    medicine: medicine ?? this.medicine,
    windDown: windDown ?? this.windDown,
    medicineName: medicineName ?? this.medicineName,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'morningCheckIn': morningCheckIn.totalMinutes,
    'medicine': medicine.totalMinutes,
    'windDown': windDown.totalMinutes,
    'medicineName': medicineName,
    'enabled': enabled,
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    morningCheckIn: TimeOfDayMinutes.fromTotal(
      j['morningCheckIn'] as int? ?? 420,
    ),
    medicine: TimeOfDayMinutes.fromTotal(j['medicine'] as int? ?? 510),
    windDown: TimeOfDayMinutes.fromTotal(j['windDown'] as int? ?? 1260),
    medicineName: j['medicineName'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? true,
  );
}

/// Which side of the family this phone is.
enum DeviceRole { appa, family }
