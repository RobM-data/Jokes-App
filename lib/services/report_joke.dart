import 'package:flutter/material.dart';

Future<void> reportJoke(
  String jokeId,
  String reason,
  String deviceUserId,
  supabase,
) async {
  debugPrint('reportJoke started');

  try {
    await supabase.from('reports').insert({
      'user_id': deviceUserId,
      'joke_id': jokeId,
      'reason': reason,
      'status': 'pending'
    });

    debugPrint('Reports table logged');
  } catch (e, st) {
    debugPrint('Joke report FAILED: $e\n$st');
  }
}
