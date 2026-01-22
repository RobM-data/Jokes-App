import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class JokeService {
  final SupabaseClient _supabase;
  final _rng = Random();

  JokeService(this._supabase);

  Future<List<Map<String, dynamic>>> fetchJokes({
    int limit = 10,
    int finalCount = 10,
    int windowSize = 1000,
  }) async {
    // get number of rows in jokes table
    final countResponse = 202000;

    final maxOffset = countResponse - windowSize;
    final offset = _rng.nextInt(maxOffset);

    final windowData = await _supabase
        .from('jokes')
        .select('id, text')
        .range(offset, offset + windowSize - 1);

    final List<Map<String, dynamic>> jokes =
        (windowData as List).cast<Map<String, dynamic>>();

    jokes.shuffle(_rng);

    return jokes.take(finalCount).toList();
  }
}
