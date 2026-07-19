/// Logique d'ancrage arabe (indépendante de Vosk, donc testable seule).
///
/// - `normalize` retire les diacritiques et unifie alef/hamza pour que la
///   comparaison de mots soit robuste (les sorties d'ASR n'ont pas de voyelles).
/// - `find` repère les instants des takbir / bismillah / salam.
/// - `keepIntervals` construit les intervalles de récitation à conserver.
class ArabicAnchors {
  ArabicAnchors._();

  // Diacritiques arabes (harakat, tanwin, shadda, sukun, tatweel…).
  static bool _isDiacritic(int c) =>
      (c >= 0x0610 && c <= 0x061A) ||
      (c >= 0x064B && c <= 0x065F) ||
      c == 0x0670 ||
      c == 0x0640;

  static const Map<String, String> _map = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
    'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي',
  };

  static String normalize(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (_isDiacritic(rune)) continue;
      final ch = String.fromCharCode(rune);
      buf.write(_map[ch] ?? ch);
    }
    return buf.toString().trim();
  }

  static const _takbir = {'اكبر'};
  static const _allah = {'الله', 'اللاه'};
  static const _bism = {'بسم'};
  static const _salam = {'السلام', 'سلام'};

  /// [words] = liste de (motNormalisé, instantDébutSecondes).
  static AnchorSet find(List<(String, double)> words) {
    final takbir = <double>[];
    final bism = <double>[];
    final salam = <double>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i].$1;
      final t = words[i].$2;
      final prev = i > 0 ? words[i - 1].$1 : '';
      final next = i + 1 < words.length ? words[i + 1].$1 : '';
      // « allah » + « akbar »
      if (_takbir.contains(w) && _allah.contains(prev)) takbir.add(t);
      if (_allah.contains(w) && _takbir.contains(next)) takbir.add(t);
      if (_bism.contains(w)) bism.add(t);
      if (_salam.contains(w)) salam.add(t);
    }
    return AnchorSet(_dedup(takbir), _dedup(bism), _dedup(salam));
  }

  static List<double> _dedup(List<double> a) {
    final s = [...a]..sort();
    final out = <double>[];
    for (final t in s) {
      if (out.isEmpty || t - out.last > 2.0) out.add(t);
    }
    return out;
  }

  /// Intervalles à garder : de chaque « Bismillah » au « Allahu Akbar » suivant.
  /// Filtre les passages trop courts pour contenir Al-Fatiha, et tronque tout
  /// ce qui suit le salam final.
  static List<(double, double)> keepIntervals({
    required List<double> bism,
    required List<double> takbir,
    required List<double> salam,
    required double totalSeconds,
    double minKeep = 25.0,
  }) {
    final cuts = [...takbir]..sort();
    final starts = [...bism]..sort();
    final raw = <(double, double)>[];
    for (final s in starts) {
      final end = cuts.firstWhere((t) => t > s + 5, orElse: () => totalSeconds);
      raw.add((s, end));
    }
    raw.sort((a, b) => a.$1.compareTo(b.$1));

    final merged = <(double, double)>[];
    for (final iv in raw) {
      if (merged.isNotEmpty && iv.$1 <= merged.last.$2 + 1) {
        merged[merged.length - 1] = (merged.last.$1,
            iv.$2 > merged.last.$2 ? iv.$2 : merged.last.$2);
      } else {
        merged.add(iv);
      }
    }

    var kept = merged.where((iv) => iv.$2 - iv.$1 >= minKeep).toList();

    if (salam.isNotEmpty) {
      final last = salam.last;
      kept = kept
          .where((iv) => iv.$1 < last)
          .map((iv) => (iv.$1, iv.$2 < last ? iv.$2 : last))
          .toList();
    }
    return kept;
  }
}

class AnchorSet {
  final List<double> takbir;
  final List<double> bismillah;
  final List<double> salam;
  AnchorSet(this.takbir, this.bismillah, this.salam);
}
