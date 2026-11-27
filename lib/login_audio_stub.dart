import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _preference = 'login-audio';
const _audio = MethodChannel('rpg_master_set/login_audio');

Future<bool> readLoginAudioEnabled() async {
  try {
    return await SharedPreferencesAsync().getBool(_preference) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> setLoginAudioEnabled(bool enabled) async {
  try {
    await SharedPreferencesAsync().setBool(_preference, enabled);
  } catch (_) {
    // Keep the current screen preference if local storage fails.
  }
}

void playLoginAudio({required bool entering}) {
  unawaited(_play(entering));
}

Future<void> _play(bool entering) async {
  try {
    await _audio.invokeMethod<void>(entering ? 'enter' : 'typing');
  } catch (_) {
    // Sound should never interrupt login.
  }
}
