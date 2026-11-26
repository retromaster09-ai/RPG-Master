import 'dart:js_interop';

@JS('rpgLoginAudio.isEnabled')
external JSBoolean _isEnabled();

@JS('rpgLoginAudio.setEnabled')
external void _setEnabled(JSBoolean enabled);

@JS('rpgLoginAudio.play')
external void _play(JSBoolean entering);

bool get loginAudioEnabled => _isEnabled().toDart;

void setLoginAudioEnabled(bool enabled) => _setEnabled(enabled.toJS);

void playLoginAudio({required bool entering}) => _play(entering.toJS);
