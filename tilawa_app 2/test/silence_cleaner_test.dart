import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/core/models/audio_clip.dart';
import 'package:tilawa/core/plugins/builtin/silence_cleaner_plugin.dart';
import 'package:tilawa/core/audio/wav_codec.dart';

/// Construit un clip : [voix 1s][silence 1s][voix 1s] à 16 kHz.
AudioClip _synth() {
  const sr = 16000;
  final samples = Int16List(sr * 3);
  for (var i = 0; i < sr; i++) {
    // 1re seconde : ton à 220 Hz (voix).
    samples[i] = (math.sin(2 * math.pi * 220 * i / sr) * 12000).round();
    // 2e seconde : silence (déjà 0).
    // 3e seconde : ton à 220 Hz (voix).
    samples[2 * sr + i] =
        (math.sin(2 * math.pi * 220 * i / sr) * 12000).round();
  }
  return AudioClip(samples: samples, sampleRate: sr);
}

void main() {
  test('SilenceCleaner supprime bien le silence central', () async {
    final input = _synth();
    final result = await SilenceCleanerPlugin().process(input);
    // On devait retirer ~1s de silence sur 3s.
    expect(result.clip.duration.inMilliseconds,
        lessThan(input.duration.inMilliseconds - 500));
    // On conserve au moins la majorité de la voix (~2s).
    expect(result.clip.duration.inMilliseconds, greaterThan(1500));
  });

  test('WavCodec encode puis décode sans perte (aller-retour)', () {
    final input = _synth();
    final bytes = WavCodec.encodeBytes(input);
    final decoded = WavCodec.decodeBytes(bytes);
    expect(decoded.sampleRate, input.sampleRate);
    expect(decoded.samples.length, input.samples.length);
    expect(decoded.samples[100], input.samples[100]);
  });
}
