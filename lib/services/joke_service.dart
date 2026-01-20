import 'package:supabase_flutter/supabase_flutter.dart';

class JokeService {
  final SupabaseClient _supabase;

  JokeService(this._supabase);

  Future<List<Map<String, dynamic>>> fetchJokes({int limit = 10}) async {
    final data = await _supabase.from('jokes').select('text').limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
