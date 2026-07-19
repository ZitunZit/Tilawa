import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/core/plugins/builtin/recitation_arabic.dart';

void main() {
  test('normalize retire diacritiques et unifie alef/hamza', () {
    expect(ArabicAnchors.normalize('أَكْبَر'), 'اكبر');
    expect(ArabicAnchors.normalize('اللَّه'), 'الله');
    expect(ArabicAnchors.normalize('بِسْمِ'), 'بسم');
  });

  test('keepIntervals garde de Bismillah au takbir suivant, coupe le salam', () {
    // Cycle simulé : bismillah@10 -> récitation -> takbir@70 ; puis
    // bismillah@130 -> takbir@200 ; salam@260.
    final keep = ArabicAnchors.keepIntervals(
      bism: [10, 130],
      takbir: [70, 200, 205],
      salam: [260],
      totalSeconds: 300,
      minKeep: 25,
    );
    expect(keep.length, 2);
    expect(keep[0].$1, 10);
    expect(keep[0].$2, 70); // coupe au takbir
    expect(keep[1].$2, 200);
    // rien après le salam
    expect(keep.every((iv) => iv.$1 < 260), isTrue);
  });

  test('keepIntervals ignore les passages trop courts (sans Fatiha)', () {
    final keep = ArabicAnchors.keepIntervals(
      bism: [10, 100],
      takbir: [20, 170], // 1er passage = 10s (trop court), 2e = 70s
      salam: [],
      totalSeconds: 200,
      minKeep: 25,
    );
    expect(keep.length, 1);
    expect(keep[0].$1, 100);
  });

  test('find repère le takbir « allah akbar » et le bismillah', () {
    final a = ArabicAnchors.find([
      ('بسم', 1.0),
      ('الله', 1.4),
      ('الرحمن', 1.9),
      ('الله', 60.0),
      ('اكبر', 60.5),
    ]);
    expect(a.bismillah.contains(1.0), isTrue);
    expect(a.takbir.any((t) => (t - 60.0).abs() < 0.6), isTrue);
  });
}
