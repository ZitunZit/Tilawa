import 'package:intl/intl.dart';

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// Format sans locale explicite pour éviter d'avoir à initialiser les données
// de locale (initializeDateFormatting). Fonctionne partout, hors-ligne.
String formatDate(DateTime dt) => DateFormat('d MMM yyyy · HH:mm').format(dt);
