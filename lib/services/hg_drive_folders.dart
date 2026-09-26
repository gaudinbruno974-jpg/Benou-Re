// Dossiers Drive des tenues et des répertoires d'un corps de Hauts Grades —
// même mécanique que les loges bleues (DriveService.ensureFolderAndUpload,
// drive_service.dart) : un dossier par tenue, créé à la planification, dont
// l'identifiant est mémorisé dans la tenue (driveFolderId/driveFolderUrl)
// puis réutilisé par tous les archivages suivants. Nom du dossier :
// « N12 5D 04 10 2026 » (numéro sur 2 chiffres, degré, date jj mm aaaa).
import 'dart:typed_data';

import '../models/hg_body.dart';
import '../models/session.dart';
import 'drive_service.dart';
import 'hg_body_service.dart';

/// Dossier parent (sous la racine SSTR) qui contient un dossier par tenue.
List<String> hgTenuesDrivePath(HgBody body) => body.key == kIahMes.key
    ? const ['IAH-MES', '09 Tenues et PV']
    : ['Tenues ${body.label}'];

/// Dossier (sous la racine SSTR) des exports Excel des répertoires.
List<String> hgRepertoiresDrivePath(HgBody body) => body.key == kIahMes.key
    ? const ['IAH-MES', '03 Dossier Membres']
    : ['Repertoires ${body.label}'];

int _degreeOf(Session s) => int.tryParse(s.degreTravail ?? s.degree) ?? 4;

int _chronoOf(Session s) {
  if (s.chrono != null) return s.chrono!.toInt();
  return int.tryParse(
        (s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
      ) ??
      0;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// « N12 5D 04 10 2026 » : numéro de la tenue, degré, date. La date est
/// omise si la tenue n'en a pas encore.
String hgSessionFolderName(Session s) {
  final dt = s.dateTime;
  final parts = [
    'N${_two(_chronoOf(s))}',
    '${_degreeOf(s)}D',
    if (dt != null) '${_two(dt.day)} ${_two(dt.month)} ${dt.year}',
  ];
  return parts.join(' ');
}

/// Suffixe des noms de fichiers archivés, comme les loges bleues
/// (« 04 10 26 »), avec le degré à la place de la lettre du grade :
/// « 04 10 26 5D ». Le suffixe commence par une espace.
String hgDriveFileSuffix(Session s) {
  final dt = s.dateTime;
  final parts = [
    if (dt != null) '${_two(dt.day)} ${_two(dt.month)} ${_two(dt.year % 100)}',
    '${_degreeOf(s)}D',
  ];
  return ' ${parts.join(' ')}';
}

/// Archive [files] (nom de fichier -> contenu PDF) dans le dossier Drive de
/// la tenue, créé au besoin, et mémorise son identifiant dans la tenue
/// (Firestore) s'il n'y était pas encore. Renvoie l'e-mail Google utilisé.
Future<String> archiveHgSessionFiles(
  HgBody body,
  Session session,
  Map<String, Uint8List> files,
) async {
  final res = await DriveService.instance.ensureHgSessionFolderAndUpload(
    parentPath: hgTenuesDrivePath(body),
    folderName: hgSessionFolderName(session),
    knownFolderId: session.driveFolderId,
    files: files,
  );
  if (session.driveFolderId != res.folderId) {
    final map = session.toMap();
    map['driveFolderId'] = res.folderId;
    map['driveFolderUrl'] = res.folderUrl;
    await HgBodyService.instance.updateSession(
      body,
      Session.fromMap(session.id, map),
    );
  }
  return res.email;
}
