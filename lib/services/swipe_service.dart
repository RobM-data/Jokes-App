import 'package:flutter/material.dart';

Future<void> updateSwipes(
  String jokeId,
  String action,
  String deviceUserId,
  supabase,
) async {
  debugPrint('updateSwipes started');

  try {
    final res1 = await supabase.from('swipes').upsert({
      'user_id': deviceUserId,
      'joke_id': jokeId,
      'action': action,
    }).select();

    debugPrint('Swipes table logged: $res1');

    final res2 = await supabase.rpc('increment_joke_likes', params: {'joke_id': jokeId, 'action': action});

    debugPrint('Jokes table logged: $res2');
  } catch (e, st) {
    debugPrint('Swipe log FAILED: $e\n$st');
  }
}
