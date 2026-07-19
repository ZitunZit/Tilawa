import 'dart:io';
import 'dart:typed_data';
import '../models/audio_clip.dart';

/// Lecture/écriture de fichiers WAV PCM 16 bits, en pur Dart (hors-ligne,
/// sans dépendance native). Gère le mono directement et convertit le stéréo
/// en mono par moyenne des canaux.
class WavCodec {
  /// Charge un WAV depuis le disque en [AudioClip] mono 16 bits.
  static Future<AudioClip> decodeFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return decodeBytes(bytes);
  }

  static AudioClip decodeBytes(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    if (bytes.lengthInBytes < 44) {
      throw const FormatException('Fichier WAV trop court / invalide.');
    }
    // "RIFF" .... "WAVE"
    // On parcourt les chunks pour trouver "fmt " et "data".
    int sampleRate = 44100;
    int channels = 1;
    int bitsPerSample = 16;
    int dataOffset = -1;
    int dataLength = 0;

    int pos = 12; // saute RIFF header (12 octets)
    while (pos + 8 <= bytes.lengthInBytes) {
      final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final size = bd.getUint32(pos + 4, Endian.little);
      final body = pos + 8;
      if (id == 'fmt ') {
        channels = bd.getUint16(body + 2, Endian.little);
        sampleRate = bd.getUint32(body + 4, Endian.little);
        bitsPerSample = bd.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = body;
        dataLength = size;
        break;
      }
      pos = body + size + (size.isOdd ? 1 : 0);
    }
    if (dataOffset < 0) {
      throw const FormatException('Chunk "data" introuvable dans le WAV.');
    }
    if (bitsPerSample != 16) {
      throw FormatException('Seul le PCM 16 bits est géré (reçu '
          '$bitsPerSample bits). Ré-encodez en 16 bits.');
    }

    final totalSamples = dataLength ~/ 2;
    final interleaved = Int16List(totalSamples);
    for (var i = 0; i < totalSamples; i++) {
      interleaved[i] = bd.getInt16(dataOffset + i * 2, Endian.little);
    }

    if (channels <= 1) {
      return AudioClip(samples: interleaved, sampleRate: sampleRate);
    }
    // Down-mix vers mono.
    final frames = totalSamples ~/ channels;
    final mono = Int16List(frames);
    for (var f = 0; f < frames; f++) {
      int acc = 0;
      for (var c = 0; c < channels; c++) {
        acc += interleaved[f * channels + c];
      }
      mono[f] = (acc / channels).round();
    }
    return AudioClip(samples: mono, sampleRate: sampleRate);
  }

  /// Écrit un [AudioClip] mono 16 bits dans un fichier WAV.
  static Future<void> encodeFile(AudioClip clip, String filePath) async {
    final bytes = encodeBytes(clip);
    await File(filePath).writeAsBytes(bytes, flush: true);
  }

  static Uint8List encodeBytes(AudioClip clip) {
    const channels = 1;
    const bitsPerSample = 16;
    final sampleRate = clip.sampleRate;
    final dataLength = clip.samples.length * 2;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    final out = BytesBuilder();
    void str(String s) => out.add(s.codeUnits);
    void u32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    void u16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    str('RIFF');
    u32(36 + dataLength);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(channels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);
    str('data');
    u32(dataLength);

    final pcm = ByteData(dataLength);
    for (var i = 0; i < clip.samples.length; i++) {
      pcm.setInt16(i * 2, clip.samples[i], Endian.little);
    }
    out.add(pcm.buffer.asUint8List());
    return out.toBytes();
  }
}
