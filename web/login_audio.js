(() => {
  const storageKey = 'rpg-master-set:login-audio';
  const AudioEngine = window.AudioContext || window.webkitAudioContext;
  let enabled = false;
  let context;
  let output;
  let lastTap = -Infinity;
  let tapNote = 0;

  try {
    enabled = localStorage.getItem(storageKey) === 'on';
  } catch {
    // Use the current page preference if local storage is unavailable.
  }

  function tone(frequency, time, duration, volume) {
    const bell = context.createOscillator();
    const overtone = context.createOscillator();
    const harmonic = context.createGain();
    const envelope = context.createGain();

    bell.frequency.value = frequency;
    overtone.frequency.value = frequency * 2.38;
    harmonic.gain.value = 0.13;
    envelope.gain.setValueAtTime(0.0001, time);
    envelope.gain.exponentialRampToValueAtTime(volume, time + 0.006);
    envelope.gain.exponentialRampToValueAtTime(0.0001, time + duration);

    bell.connect(envelope);
    overtone.connect(harmonic).connect(envelope);
    envelope.connect(output);
    for (const oscillator of [bell, overtone]) {
      oscillator.start(time);
      oscillator.stop(time + duration);
    }
    bell.onended = () => envelope.disconnect();
  }

  function play(entering) {
    if (!enabled || !AudioEngine) return;
    const now = performance.now();
    if (!entering && now - lastTap < 58) return;
    if (!entering) lastTap = now;

    try {
      if (!context) {
        context = new AudioEngine();
        output = context.createGain();
        output.connect(context.destination);
      }
      if (context.state === 'suspended') context.resume().catch(() => {});
      const time = context.currentTime + 0.01;
      if (entering) {
        tone(523.25, time, 0.20, 0.08);
        tone(659.25, time + 0.06, 0.25, 0.07);
        tone(783.99, time + 0.12, 0.32, 0.07);
        return;
      }

      const taps = [1318.51, 1567.98, 1760];
      tone(taps[tapNote], time, 0.075, 0.035);
      tapNote = (tapNote + 1) % taps.length;
    } catch {
      // The login can still be used if the browser blocks audio.
    }
  }

  window.rpgLoginAudio = {
    isEnabled: () => enabled,
    setEnabled(value) {
      enabled = value;
      if (output) output.gain.value = enabled ? 1 : 0;
      try {
        localStorage.setItem(storageKey, enabled ? 'on' : 'off');
      } catch {
        // The switch remains usable for this page.
      }
    },
    play,
  };
})();
