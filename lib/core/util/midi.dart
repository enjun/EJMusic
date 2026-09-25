/// 音名与 MIDI 编号换算。
library;

/// MIDI：C4=60（科学音高记谱）。A0=21, C8=108。
int pitchToMidi(String step, int alter, int octave) {
  const semis = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  final base = semis[step.toUpperCase()];
  if (base == null) throw ArgumentError('非法音名: $step');
  return (octave + 1) * 12 + base + alter;
}

/// MIDI → 音名（升号优先）。返回 (step, alter, octave)。
(String, int, int) midiToPitch(int midi) {
  const names = ['C', 'C', 'D', 'D', 'E', 'F', 'F', 'G', 'G', 'A', 'A', 'B'];
  final pc = ((midi % 12) + 12) % 12;
  final octave = (midi ~/ 12) - 1;
  final step = names[pc];
  final alter = (pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10) ? 1 : 0;
  return (step, alter, octave);
}

/// 吉他六弦空弦 MIDI（1 弦=高音 E4=64 … 6 弦=低音 E2=40）。
const guitarOpenStringMidi = [64, 59, 55, 50, 45, 40];

int tabToMidi(int guitarString, int fret) =>
    guitarOpenStringMidi[guitarString - 1] + fret;
