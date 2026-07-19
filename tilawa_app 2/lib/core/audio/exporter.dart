import 'dart:io';
import 'package:share_plus/share_plus.dart';

/// Partage/export via les mécanismes natifs de chaque plateforme
/// (WhatsApp, mail, cloud, enregistrement local…), grâce à `share_plus`.
///
/// Par défaut on partage le WAV nettoyé. Pour partager en MP3/FLAC, la
/// conversion est confiée à un [ExporterPlugin] (voir plugins), afin de
/// garder le cœur sans dépendance à un encodeur lourd.
class Exporter {
  /// Ouvre la feuille de partage native pour le fichier donné.
  static Future<void> share(String filePath, {String? subject}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Fichier introuvable : $filePath');
    }
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: subject ?? 'Récitation (Tilawa)',
      text: 'Récitation nettoyée avec Tilawa.',
    );
  }
}
