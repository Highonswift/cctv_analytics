import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Optional family sync over Supabase (free tier: 500 MB database, 1 GB file
/// storage, anonymous sign-in). Without it the app is fully usable on one
/// phone; with it, family members hear Appa's stories on their own phones
/// and send voice replies back.
///
/// Schema and row-level security: `supabase/schema.sql`. Every row and every
/// voice file is scoped to one household; a phone joins a household with a
/// six-character code shown on Appa's phone.
abstract class FamilySync {
  bool get connected;
  String? get householdCode;

  Future<void> connect({required String url, required String key});

  /// Appa's phone: create the household and get its join code.
  Future<String> createHousehold({required String displayName});

  /// A family phone: join with the code from Appa's phone.
  Future<void> joinHousehold({
    required String code,
    required String displayName,
  });

  /// Restore a previous session's household on app start.
  Future<void> resume({required String householdCode});

  // Appa side
  Future<String> uploadStory(Story story);
  Future<List<RemoteReply>> fetchReplies();
  Future<String> downloadToFile(String remotePath, String localPath);
  Future<void> markReplyHeard(String replyId);

  // Family side
  Future<List<RemoteStory>> fetchStories();
  Future<void> uploadReply({
    required String storyId,
    required String localPath,
    required String authorName,
  });
  Future<String> signedUrl(String remotePath);
}

class RemoteStory {
  RemoteStory({
    required this.id,
    required this.promptText,
    required this.audioPath,
    required this.createdAt,
    required this.replyAuthors,
  });
  final String id;
  final String promptText;
  final String audioPath;
  final DateTime createdAt;
  final List<String> replyAuthors;
}

class RemoteReply {
  RemoteReply({
    required this.id,
    required this.storyId,
    required this.authorName,
    required this.audioPath,
    required this.createdAt,
    required this.listened,
  });
  final String id;
  final String storyId;
  final String authorName;
  final String audioPath;
  final DateTime createdAt;
  final bool listened;
}

class SupabaseFamilySync implements FamilySync {
  static const bucket = 'voice';

  SupabaseClient? _client;
  String? _householdId;
  String? _code;

  @override
  bool get connected => _client != null && _householdId != null;

  @override
  String? get householdCode => _code;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw StateError('Family sync is not connected');
    return c;
  }

  String get _hh {
    final h = _householdId;
    if (h == null) throw StateError('No household yet');
    return h;
  }

  @override
  Future<void> connect({required String url, required String key}) async {
    if (_client != null) return;
    try {
      await Supabase.initialize(url: url, publishableKey: key);
    } on AssertionError {
      // Already initialised in this process.
    }
    _client = Supabase.instance.client;
    if (_c.auth.currentSession == null) {
      await _c.auth.signInAnonymously();
    }
  }

  @override
  Future<String> createHousehold({required String displayName}) async {
    final res = await _c.rpc(
      'create_household',
      params: {'p_display_name': displayName},
    );
    final row = Map<String, dynamic>.from((res as List).first as Map);
    _householdId = row['household_id'] as String;
    _code = row['join_code'] as String;
    return _code!;
  }

  @override
  Future<void> joinHousehold({
    required String code,
    required String displayName,
  }) async {
    final res = await _c.rpc(
      'join_household',
      params: {
        'p_code': code.trim().toUpperCase(),
        'p_display_name': displayName,
      },
    );
    _householdId = res as String;
    _code = code.trim().toUpperCase();
  }

  @override
  Future<void> resume({required String householdCode}) async {
    final res = await _c.rpc('my_household');
    if (res == null) throw StateError('This phone is not in a household');
    _householdId = res as String;
    _code = householdCode;
  }

  @override
  Future<String> uploadStory(Story story) async {
    final local = story.localAudioPath;
    if (local == null) throw StateError('Story has no audio');
    final path = '$_hh/stories/${story.id}.m4a';
    await _c.storage
        .from(bucket)
        .upload(
          path,
          File(local),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await _c.from('stories').upsert({
      'id': story.id,
      'household_id': _hh,
      'prompt_id': story.promptId,
      'prompt_text': story.promptText,
      'audio_path': path,
      'created_at': story.createdAt.toUtc().toIso8601String(),
    });
    return path;
  }

  @override
  Future<List<RemoteReply>> fetchReplies() async {
    final rows = await _c
        .from('replies')
        .select('id, story_id, author_name, audio_path, created_at, listened')
        .eq('household_id', _hh)
        .order('created_at');
    return [
      for (final r in rows)
        RemoteReply(
          id: r['id'] as String,
          storyId: r['story_id'] as String,
          authorName: r['author_name'] as String? ?? '',
          audioPath: r['audio_path'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          listened: r['listened'] as bool? ?? false,
        ),
    ];
  }

  @override
  Future<String> downloadToFile(String remotePath, String localPath) async {
    final bytes = await _c.storage.from(bucket).download(remotePath);
    final f = File(localPath);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    return localPath;
  }

  @override
  Future<void> markReplyHeard(String replyId) async {
    await _c.from('replies').update({'listened': true}).eq('id', replyId);
  }

  @override
  Future<List<RemoteStory>> fetchStories() async {
    final rows = await _c
        .from('stories')
        .select('id, prompt_text, audio_path, created_at, replies(author_name)')
        .eq('household_id', _hh)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        RemoteStory(
          id: r['id'] as String,
          promptText: r['prompt_text'] as String? ?? '',
          audioPath: r['audio_path'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          replyAuthors: [
            for (final rep in (r['replies'] as List? ?? []))
              (rep as Map)['author_name'] as String? ?? '',
          ],
        ),
    ];
  }

  @override
  Future<void> uploadReply({
    required String storyId,
    required String localPath,
    required String authorName,
  }) async {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}-${authorName.hashCode.abs()}';
    final path = '$_hh/replies/$storyId/$id.m4a';
    await _c.storage
        .from(bucket)
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await _c.from('replies').insert({
      'story_id': storyId,
      'household_id': _hh,
      'author_name': authorName,
      'audio_path': path,
    });
  }

  @override
  Future<String> signedUrl(String remotePath) =>
      _c.storage.from(bucket).createSignedUrl(remotePath, 60 * 60);
}

/// Used when sync is not set up. Every remote call is a quiet no-op.
class NoFamilySync implements FamilySync {
  @override
  bool get connected => false;
  @override
  String? get householdCode => null;
  @override
  Future<void> connect({required String url, required String key}) async =>
      debugPrint('Family sync not available in this build');
  @override
  Future<String> createHousehold({required String displayName}) =>
      throw UnsupportedError('no sync');
  @override
  Future<void> joinHousehold({
    required String code,
    required String displayName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<void> resume({required String householdCode}) async {}
  @override
  Future<String> uploadStory(Story story) => throw UnsupportedError('no sync');
  @override
  Future<List<RemoteReply>> fetchReplies() async => [];
  @override
  Future<String> downloadToFile(String remotePath, String localPath) =>
      throw UnsupportedError('no sync');
  @override
  Future<void> markReplyHeard(String replyId) async {}
  @override
  Future<List<RemoteStory>> fetchStories() async => [];
  @override
  Future<void> uploadReply({
    required String storyId,
    required String localPath,
    required String authorName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<String> signedUrl(String remotePath) =>
      throw UnsupportedError('no sync');
}
