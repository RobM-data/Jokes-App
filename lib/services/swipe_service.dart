import 'package:flutter/material.dart';

Future<void> updateSwipes(String jokeId, String action, String deviceUserId, supabase) async {
    debugPrint('updateSwipes started');

    try {
      final res = await supabase.from('swipes').upsert({
        'user_id': deviceUserId,
        'joke_id': jokeId,
        'action': action,
      }).select();

      debugPrint('Swipe logged: $res');
    } catch (e, st) {
      debugPrint('Swipe log FAILED: $e\n$st');
    }
  }