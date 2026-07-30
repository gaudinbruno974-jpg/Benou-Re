// Archivage Google Drive natif (porté depuis src/lib/googleDrive.ts).
//
// Sur le web, l'app utilise signInWithPopup ; en natif (Android) on passe par
// google_sign_in pour obtenir un jeton d'accès avec la portée Drive, puis on
// appelle l'API REST Drive v3 (recherche/création de dossier + upload
// multipart), comme le fait la version web.
//
// Prérequis côté console (voir flutter_app/README.md) :
//  - fournisseur Google activé dans Firebase Authentication ;
//  - empreinte SHA-1 de la clé de signature ajoutée à l'app Android Firebase
//    (cela crée automatiquement le client OAuth Android) ;
//  - API Google Drive activée dans Google Cloud + votre compte ajouté comme
//    utilisateur de test sur l'écran de consentement OAuth.
import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/session.dart';

/// Dossier Drive parent partagé (identique au web).
const String kDriveParentFolderId = '11Qp8SXLFG0Spfks-G6OAQ66EHMGjEOgy';

class DriveException implements Exception {
  final String message;
  DriveException(this.message);
  @override
  String toString() => message;
}

class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'https://www.googleapis.com/auth/drive',
      'email',
    ],
  );

  String? get currentEmail => _gsi.currentUser?.email;

  bool get isConnected => _gsi.currentUser != null;

  Future<void> disconnect() => _gsi.signOut();

  /// Connexion Google (interactive) et récupération des en-têtes d'auth.
  Future<Map<String, String>> _authHeaders() async {
    GoogleSignInAccount? account = _gsi.currentUser;
    account ??= await _gsi.signInSilently();
    account ??= await _gsi.signIn();
    if (account == null) {
      throw DriveException('Connexion Google annulée.');
    }
    final headers = await account.authHeaders;
    if (!headers.containsKey('Authorization')) {
      throw DriveException("Impossible d'obtenir le jeton d'accès Google.");
    }
    return headers;
  }

  /// Nom du dossier de la tenue : « Tenue {chrono} {jj} {mm} {annee} ».
  static String folderName(Session session) {
    final numOnly =
        (session.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final chrono = numOnly.isNotEmpty ? numOnly.padLeft(2, '0') : '03';
    var jj = '01', mm = '01', annee = '2026';
    final dateValue = session.date.isNotEmpty
        ? session.date
        : (session.dateReprise ?? '');
    if (dateValue.isNotEmpty) {
      final parts = dateValue.split('T').first.split('-');
      if (parts.length == 3) {
        annee = parts[0];
        mm = parts[1];
        jj = parts[2];
      } else {
        final d = DateTime.tryParse(dateValue);
        if (d != null) {
          jj = d.day.toString().padLeft(2, '0');
          mm = d.month.toString().padLeft(2, '0');
          annee = d.year.toString();
        }
      }
    }
    return 'Tenue $chrono $jj $mm $annee';
  }

  Future<String> _findOrCreateFolder(
      Map<String, String> headers, String name, String parentId) async {
    final escaped = name.replaceAll("'", "\\'");
    final q =
        "mimeType='application/vnd.google-apps.folder' and name='$escaped' "
        "and '$parentId' in parents and trashed = false";
    final searchUri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id,name)');
    final searchRes = await http.get(searchUri, headers: headers);
    if (searchRes.statusCode != 200) {
      throw DriveException('Erreur recherche dossier : ${searchRes.body}');
    }
    final files = (jsonDecode(searchRes.body)['files'] as List?) ?? [];
    if (files.isNotEmpty) {
      return files.first['id'] as String;
    }
    final createRes = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [parentId],
      }),
    );
    if (createRes.statusCode != 200) {
      throw DriveException('Erreur création dossier : ${createRes.body}');
    }
    return jsonDecode(createRes.body)['id'] as String;
  }

  Future<void> _uploadPdf(Map<String, String> headers, String folderId,
      String fileName, Uint8List bytes) async {
    const boundary = 'benoure_drive_boundary';
    final meta = jsonEncode({
      'name': fileName,
      'parents': [folderId],
    });
    final body = <int>[];
    body.addAll(utf8.encode(
        '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n'));
    body.addAll(utf8
        .encode('--$boundary\r\nContent-Type: application/pdf\r\n\r\n'));
    body.addAll(bytes);
    body.addAll(utf8.encode('\r\n--$boundary--'));

    final res = await http.post(
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    if (res.statusCode != 200) {
      throw DriveException('Erreur upload « $fileName » : ${res.body}');
    }
  }

  /// Archive une liste de PDF dans le dossier de la tenue.
  /// [files] : nom de fichier -> contenu PDF.
  /// Renvoie l'e-mail Google utilisé.
  Future<String> archivePdfs(
      Session session, Map<String, Uint8List> files) async {
    final res = await ensureFolderAndUpload(session, files);
    return res.email;
  }

  /// Crée (ou retrouve) le dossier Drive de la tenue, y dépose [files] et
  /// renvoie l'identifiant, l'URL du dossier et l'e-mail Google utilisé.
  Future<({String folderId, String folderUrl, String email})>
      ensureFolderAndUpload(
          Session session, Map<String, Uint8List> files) async {
    final headers = await _authHeaders();
    final folderId = await _findOrCreateFolder(
        headers, folderName(session), kDriveParentFolderId);
    for (final entry in files.entries) {
      await _uploadPdf(headers, folderId, entry.key, entry.value);
    }
    return (
      folderId: folderId,
      folderUrl: 'https://drive.google.com/drive/folders/$folderId',
      email: currentEmail ?? 'compte Google',
    );
  }
}
