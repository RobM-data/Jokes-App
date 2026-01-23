import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class JokeService {
  final SupabaseClient _supabase;
  final _rng = Random();

  JokeService(this._supabase);

  /// Returns a list of joke_ids the user has swiped
  Future<List<String>> swipedIds(String userId) async {
    final data = await _supabase
        .from('swipes')
        .select('joke_id')
        .eq('user_id', userId);

    final List<Map<String, dynamic>> rows = (data as List).cast<Map<String, dynamic>>();
    return rows.map((row) => row['joke_id'].toString()).toList();
  }

  /// Fetch random jokes the user hasn't swiped yet
  Future<List<Map<String, dynamic>>> fetchJokes({
    int limit = 10,
    int windowSize = 1000,
    required String userId,
  }) async {
    // get list of joke_ids already swiped
    final swiped = await swipedIds(userId);

    // get number of rows in jokes table (or you can fetch dynamically)
    final countResponse = 202000;
    final maxOffset = countResponse - windowSize;
    final offset = _rng.nextInt(maxOffset);

    final windowData = await _supabase
        .from('jokes')
        .select('id, text')
        .not('id', 'in', swiped) // <-- pass the awaited list
        .range(offset, offset + windowSize - 1);

    final List<Map<String, dynamic>> jokes = (windowData as List).cast<Map<String, dynamic>>();

    jokes.shuffle(_rng);

    return jokes.take(limit).toList();
  }
}
