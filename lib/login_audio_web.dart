import 'dart:js_interop';

@JS('rpgLoginAudio.isEnabled')
external JSBoolean _isEnabled();

@JS('rpgLoginAudio.setEnabled')
external void _setEnabled(JSBoolean enabled);

@JS('rpgLoginAudio.play')
external void _play(JSBoolean entering);

Future<bool> readLoginAudioEnabled() async => _isEnabled().toDart;

Future<void> setLoginAudioEnabled(bool enabled) async =>
    _setEnabled(enabled.toJS);

void playLoginAudio({required bool entering}) => _play(entering.toJS);
