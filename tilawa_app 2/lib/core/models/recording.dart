/// Une entrée de la bibliothèque : un enregistrement brut et/ou nettoyé.
class Recording {
  final String id;
  final String? label; // ex. "Isha", "Fajr" — optionnel
  final DateTime createdAt;
  final Duration duration;

  /// Chemin du fichier brut (WAV) tel qu'enregistré ou importé.
  final String rawPath;

  /// Chemin du fichier nettoyé (WAV), null tant que non traité.
  final String? cleanedPath;

  /// Durée du fichier nettoyé (utile pour montrer le gain).
  final Duration? cleanedDuration;

  const Recording({
    required this.id,
    required this.createdAt,
    required this.duration,
    required this.rawPath,
    this.label,
    this.cleanedPath,
    this.cleanedDuration,
  });

  bool get isCleaned => cleanedPath != null;

  Recording copyWith({
    String? label,
    String? cleanedPath,
    Duration? cleanedDuration,
  }) {
    return Recording(
      id: id,
      createdAt: createdAt,
      duration: duration,
      rawPath: rawPath,
      label: label ?? this.label,
      cleanedPath: cleanedPath ?? this.cleanedPath,
      cleanedDuration: cleanedDuration ?? this.cleanedDuration,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'label': label,
        'created_at': createdAt.millisecondsSinceEpoch,
        'duration_ms': duration.inMilliseconds,
        'raw_path': rawPath,
        'cleaned_path': cleanedPath,
        'cleaned_duration_ms': cleanedDuration?.inMilliseconds,
      };

  factory Recording.fromMap(Map<String, Object?> m) => Recording(
        id: m['id'] as String,
        label: m['label'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        duration: Duration(milliseconds: m['duration_ms'] as int),
        rawPath: m['raw_path'] as String,
        cleanedPath: m['cleaned_path'] as String?,
        cleanedDuration: m['cleaned_duration_ms'] == null
            ? null
            : Duration(milliseconds: m['cleaned_duration_ms'] as int),
      );
}
