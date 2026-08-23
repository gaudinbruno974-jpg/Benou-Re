// Session Google partagée (Drive + Gmail), portée depuis
// src/lib/googleDrive.ts pour Drive puis étendue à la création de brouillons
// Gmail avec pièce jointe (voir createGmailDraftWithAttachment).
//
// Sur le web, l'app utilise signInWithPopup ; en natif (Android) on passe par
// google_sign_in pour obtenir un jeton d'accès avec les portées Drive/Gmail,
// puis on appelle les API REST correspondantes (recherche/création de
// dossier + upload multipart pour Drive ; création de brouillon MIME pour
// Gmail), comme le fait la version web.
//
// Prérequis côté console (voir flutter_app/README.md) :
//  - fournisseur Google activé dans Firebase Authentication ;
//  - empreinte SHA-1 de la clé de signature ajoutée à l'app Android Firebase
//    (cela crée automatiquement le client OAuth Android) ;
//  - API Google Drive + Gmail activées dans Google Cloud + votre compte
//    ajouté comme utilisateur de test sur l'écran de consentement OAuth.
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/lodge_config.dart';
import '../firebase_options.dart';
import '../models/session.dart';

class DriveException implements Exception {
  final String message;
  DriveException(this.message);
  @override
  String toString() => message;
}

class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive',
    // Créer/modifier des brouillons et envoyer des messages — pas d'accès en
    // lecture à la boîte de réception.
    'https://www.googleapis.com/auth/gmail.compose',
    'email',
  ];

  final GoogleSignIn _gsi = GoogleSignIn(scopes: _scopes);

  /// Jeton d'accès Drive obtenu sur le web (valable le temps de la session).
  String? _webToken;
  String? _webEmail;

  String? get currentEmail => _gsi.currentUser?.email ?? _webEmail;

  bool get isConnected => _gsi.currentUser != null;

  Future<void> disconnect() => _gsi.signOut();

  /// Demande l'autorisation Google Drive si nécessaire et vérifie que l'accès
  /// est disponible avant d'essayer de créer ou télécharger le PDF.
  Future<void> ensureDriveAuthorization() async {
    await _authHeaders();
  }

  /// Connexion Google (interactive) et récupération des en-têtes d'auth.
  Future<Map<String, String>> _authHeaders() async {
    if (kIsWeb) return _webAuthHeaders();
    GoogleSignInAccount? account;
    try {
      account =
          _gsi.currentUser ??
          await _gsi.signInSilently() ??
          await _gsi.signIn();
    } on DriveException {
      rethrow;
    } catch (e) {
      // Sur le web, une configuration OAuth absente ou un domaine non autorisé
      // remontent sous forme d'erreurs techniques peu lisibles.
      throw DriveException('Connexion Google impossible : $e');
    }
    if (account == null) {
      throw DriveException('Connexion Google annulée.');
    }
    final headers = await account.authHeaders;
    if (!headers.containsKey('Authorization')) {
      throw DriveException("Impossible d'obtenir le jeton d'accès Google.");
    }
    return headers;
  }

  /// Sur le web, le greffon `google_sign_in` échoue avant même d'ouvrir la
  /// fenêtre Google (identité reconstruite via l'API People, non activée sur ce
  /// projet). On passe donc par Firebase Auth, qui expose directement le jeton
  /// d'accès OAuth du fournisseur Google — la méthode déjà utilisée par la
  /// version web historique.
  ///
  /// La fenêtre est ouverte sur une application Firebase secondaire pour ne pas
  /// remplacer la session du membre connecté par le compte Google choisi.
  Future<Map<String, String>> _webAuthHeaders() async {
    final cached = _webToken;
    if (cached != null && cached.isNotEmpty) {
      return _bearer(cached);
    }
    final auth = FirebaseAuth.instanceFor(app: await _driveApp());
    final provider = GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/drive')
      ..addScope('https://www.googleapis.com/auth/gmail.compose')
      ..setCustomParameters({'prompt': 'select_account'});
    final UserCredential credential;
    try {
      credential = await auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      throw DriveException('Connexion Google refusée : ${e.message ?? e.code}');
    } catch (e) {
      throw DriveException('Connexion Google impossible : $e');
    }
    final oauthCred = credential.credential as OAuthCredential?;
    if (oauthCred == null) {
      throw DriveException(
        'Impossible d\'obtenir le jeton d\'accès Google : credential absent.',
      );
    }
    final token = oauthCred.accessToken;
    if (token == null || token.isEmpty) {
      throw DriveException(
        'Impossible d\'obtenir le jeton d\'accès Google : accessToken vide.',
      );
    }
    _webToken = token;
    _webEmail = credential.user?.email;
    return _bearer(token);
  }

  Map<String, String> _bearer(String token) => {
    'Authorization': 'Bearer $token',
    'X-Goog-AuthUser': '0',
  };

  /// Application Firebase dédiée à l'autorisation Drive, créée à la demande.
  Future<FirebaseApp> _driveApp() async {
    try {
      return Firebase.app(_driveAppName);
    } on FirebaseException {
      return Firebase.initializeApp(
        name: _driveAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static const String _driveAppName = 'drive';

  /// Nom du dossier de la tenue : « Tenue {chrono} {jj} {mm} {annee} ».
  static String folderName(Session session) {
    final numOnly = (session.sessionNumber ?? '').replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
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
    Map<String, String> headers,
    String name,
    String parentId,
  ) async {
    final escaped = name.replaceAll("'", "\\'");
    final q =
        "mimeType='application/vnd.google-apps.folder' and name='$escaped' "
        "and '$parentId' in parents and trashed = false";
    final searchUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id,name)',
    );
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

  /// Identifiant d'un fichier de même nom déjà présent dans [folderId].
  Future<String?> _findFile(
    Map<String, String> headers,
    String folderId,
    String fileName,
  ) async {
    final escaped = fileName.replaceAll("'", "\\'");
    final q = "name='$escaped' and '$folderId' in parents and trashed = false";
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id,name)',
    );
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) return null;
    final files = (jsonDecode(res.body)['files'] as List?) ?? [];
    if (files.isEmpty) return null;
    return files.first['id'] as String?;
  }

  /// Déplace le dossier [folderId] dans la corbeille Drive (réversible),
  /// utilisé quand une tenue est annulée : le dossier « Tenue {chrono}
  /// {date} » ne correspond plus à rien une fois la tenue reprogrammée à
  /// une autre date.
  Future<void> trashFolder(String folderId) async {
    final headers = await _authHeaders();
    final res = await http.patch(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$folderId'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'trashed': true}),
    );
    if (res.statusCode != 200) {
      throw DriveException('Erreur suppression dossier : ${res.body}');
    }
  }

  Future<void> _uploadFile(
    Map<String, String> headers,
    String folderId,
    String fileName,
    Uint8List bytes, {
    String contentType = 'application/pdf',
  }) async {
    final existingId = await _findFile(headers, folderId, fileName);
    if (existingId != null) {
      final res = await http.patch(
        Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/$existingId?uploadType=media',
        ),
        headers: {...headers, 'Content-Type': contentType},
        body: bytes,
      );
      if (res.statusCode != 200) {
        throw DriveException('Erreur mise à jour « $fileName » : ${res.body}');
      }
      return;
    }

    const boundary = 'benoure_drive_boundary';
    final meta = jsonEncode({
      'name': fileName,
      'parents': [folderId],
    });
    final body = <int>[];
    body.addAll(
      utf8.encode(
        '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n',
      ),
    );
    body.addAll(
      utf8.encode('--$boundary\r\nContent-Type: $contentType\r\n\r\n'),
    );
    body.addAll(bytes);
    body.addAll(utf8.encode('\r\n--$boundary--'));

    final res = await http.post(
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      ),
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
    Session session,
    Map<String, Uint8List> files,
  ) async {
    final res = await ensureFolderAndUpload(session, files);
    return res.email;
  }

  /// Crée (ou retrouve) le dossier Drive de la tenue, y dépose [files] et
  /// renvoie l'identifiant, l'URL du dossier et l'e-mail Google utilisé.
  Future<({String folderId, String folderUrl, String email})>
  ensureFolderAndUpload(Session session, Map<String, Uint8List> files) async {
    try {
      return await _archive(session, files);
    } on DriveException catch (e) {
      // Jeton web expiré (valable une heure) : on redemande l'autorisation.
      if (!kIsWeb || _webToken == null || !e.message.contains('401')) rethrow;
      _webToken = null;
      return _archive(session, files);
    }
  }

  Future<({String folderId, String folderUrl, String email})> _archive(
    Session session,
    Map<String, Uint8List> files,
  ) async {
    final headers = await _authHeaders();
    final knownId = session.driveFolderId;
    final folderId = (knownId != null && knownId.trim().isNotEmpty)
        ? knownId.trim()
        : await _findOrCreateFolder(
            headers,
            folderName(session),
            // Dossier parent partagé, propre à chaque Loge.
            LodgeConfig.current.driveParentFolderId,
          );
    for (final entry in files.entries) {
      await _uploadFile(headers, folderId, entry.key, entry.value);
    }
    return (
      folderId: folderId,
      folderUrl: 'https://drive.google.com/drive/folders/$folderId',
      email: currentEmail ?? 'compte Google',
    );
  }

  /// Archive l'Appel de cotisation ou le Quitus d'un membre : dossier
  /// « {type} {année} » (ex. « Capitations 2026 »), créé au besoin sous
  /// [LodgeConfig.treasuryDriveFolderId], propre à chaque Loge.
  Future<String> archiveTreasuryDocument({
    required String type,
    required int year,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final parentId = LodgeConfig.current.treasuryDriveFolderId.trim();
    if (parentId.isEmpty) {
      throw DriveException(
        'Aucun dossier Drive de Trésorerie configuré pour cette Loge '
        '(treasuryDriveFolderId).',
      );
    }
    try {
      return await _archiveTreasuryDocument(parentId, type, year, fileName, bytes);
    } on DriveException catch (e) {
      if (!kIsWeb || _webToken == null || !e.message.contains('401')) rethrow;
      _webToken = null;
      return _archiveTreasuryDocument(parentId, type, year, fileName, bytes);
    }
  }

  Future<String> _archiveTreasuryDocument(
    String parentId,
    String type,
    int year,
    String fileName,
    Uint8List bytes,
  ) async {
    final headers = await _authHeaders();
    final folderId = await _findOrCreateFolder(headers, '$type $year', parentId);
    await _uploadFile(headers, folderId, fileName, bytes);
    return currentEmail ?? 'compte Google';
  }

  /// Archive le Passeport Maçonnique d'un membre, un fichier par membre,
  /// directement dans le dossier configuré (pas de sous-dossier annuel, ce
  /// document n'est pas rattaché à une année) — voir
  /// [LodgeConfig.passportDriveFolderId].
  Future<String> archivePassportDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final folderId = LodgeConfig.current.passportDriveFolderId.trim();
    if (folderId.isEmpty) {
      throw DriveException(
        'Aucun dossier Drive de Passeports configuré pour cette Loge '
        '(passportDriveFolderId).',
      );
    }
    try {
      return await _archivePassportDocument(folderId, fileName, bytes);
    } on DriveException catch (e) {
      if (!kIsWeb || _webToken == null || !e.message.contains('401')) rethrow;
      _webToken = null;
      return _archivePassportDocument(folderId, fileName, bytes);
    }
  }

  Future<String> _archivePassportDocument(
    String folderId,
    String fileName,
    Uint8List bytes,
  ) async {
    final headers = await _authHeaders();
    await _uploadFile(headers, folderId, fileName, bytes);
    return currentEmail ?? 'compte Google';
  }

  // ─── Gmail : envoi ou brouillon, avec pièce jointe réelle ────────────
  // Un lien mailto:/Gmail compose ne permet aucune pièce jointe (limite de
  // ces schémas d'URL, aucun contournement possible) : on passe donc par
  // l'API Gmail. Le scope gmail.compose déjà accordé couvre aussi bien la
  // création de brouillons que l'envoi direct (users.messages.send) — pas
  // de nouvelle autorisation à redemander.
  //
  // L'envoi direct (sendGmailWithAttachment) est utilisé pour les envois où
  // le contenu est entièrement généré (convocations/invitations, documents
  // de Trésorerie) : avec dix destinataires, créer dix brouillons imposait
  // de rouvrir et cliquer « Envoyer » dix fois dans Gmail après coup, ce qui
  // annulait le bénéfice de l'envoi groupé. createGmailDraftWithAttachment
  // reste disponible si un point d'appel a besoin d'une relecture manuelle
  // avant envoi.

  static const int _mimeLineLength = 76;

  /// Découpe une chaîne base64 en lignes de 76 caractères (RFC 2045), comme
  /// l'exigent les corps encodés en base64 d'un message MIME.
  static String _wrapBase64(String base64Body) {
    final buffer = StringBuffer();
    for (var i = 0; i < base64Body.length; i += _mimeLineLength) {
      final end = (i + _mimeLineLength < base64Body.length)
          ? i + _mimeLineLength
          : base64Body.length;
      buffer.write(base64Body.substring(i, end));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  /// En-tête *Subject* correctement encodé pour un sujet non-ASCII (RFC 2047).
  static String _encodedSubject(String subject) =>
      '=?UTF-8?B?${base64.encode(utf8.encode(subject))}?=';

  String _buildMimeMessage({
    required String to,
    required String subject,
    required String body,
    required String attachmentName,
    required Uint8List attachmentBytes,
  }) {
    const boundary = 'benoure_gmail_boundary';
    return 'To: $to\r\n'
        'Subject: ${_encodedSubject(subject)}\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: multipart/mixed; boundary="$boundary"\r\n'
        '\r\n'
        '--$boundary\r\n'
        'Content-Type: text/plain; charset="UTF-8"\r\n'
        'Content-Transfer-Encoding: base64\r\n'
        '\r\n'
        '${_wrapBase64(base64.encode(utf8.encode(body)))}'
        '--$boundary\r\n'
        'Content-Type: application/pdf; name="$attachmentName"\r\n'
        'Content-Disposition: attachment; filename="$attachmentName"\r\n'
        'Content-Transfer-Encoding: base64\r\n'
        '\r\n'
        '${_wrapBase64(base64.encode(attachmentBytes))}'
        '--$boundary--';
  }

  /// Crée un brouillon Gmail (destinataire, sujet, corps, PDF en pièce
  /// jointe) et renvoie l'identifiant du message, pour un lien direct vers
  /// le brouillon.
  Future<String> createGmailDraftWithAttachment({
    required String to,
    required String subject,
    required String body,
    required String attachmentName,
    required Uint8List attachmentBytes,
  }) async {
    try {
      return await _createGmailDraft(
        to,
        subject,
        body,
        attachmentName,
        attachmentBytes,
      );
    } on DriveException catch (e) {
      if (!kIsWeb || _webToken == null || !e.message.contains('401')) rethrow;
      _webToken = null;
      return _createGmailDraft(to, subject, body, attachmentName, attachmentBytes);
    }
  }

  Future<String> _createGmailDraft(
    String to,
    String subject,
    String body,
    String attachmentName,
    Uint8List attachmentBytes,
  ) async {
    final headers = await _authHeaders();
    final raw = base64Url.encode(
      utf8.encode(
        _buildMimeMessage(
          to: to,
          subject: subject,
          body: body,
          attachmentName: attachmentName,
          attachmentBytes: attachmentBytes,
        ),
      ),
    );
    final res = await http.post(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/drafts'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': {'raw': raw},
      }),
    );
    if (res.statusCode != 200) {
      throw DriveException('Erreur création du brouillon Gmail : ${res.body}');
    }
    return (jsonDecode(res.body)['message']?['id'] as String?) ?? '';
  }

  /// Envoie directement un e-mail (destinataire, sujet, corps, PDF en pièce
  /// jointe) — l'utilisateur n'a plus rien à faire dans Gmail ensuite.
  Future<String> sendGmailWithAttachment({
    required String to,
    required String subject,
    required String body,
    required String attachmentName,
    required Uint8List attachmentBytes,
  }) async {
    try {
      return await _sendGmail(to, subject, body, attachmentName, attachmentBytes);
    } on DriveException catch (e) {
      if (!kIsWeb || _webToken == null || !e.message.contains('401')) rethrow;
      _webToken = null;
      return _sendGmail(to, subject, body, attachmentName, attachmentBytes);
    }
  }

  Future<String> _sendGmail(
    String to,
    String subject,
    String body,
    String attachmentName,
    Uint8List attachmentBytes,
  ) async {
    final headers = await _authHeaders();
    final raw = base64Url.encode(
      utf8.encode(
        _buildMimeMessage(
          to: to,
          subject: subject,
          body: body,
          attachmentName: attachmentName,
          attachmentBytes: attachmentBytes,
        ),
      ),
    );
    final res = await http.post(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'raw': raw}),
    );
    if (res.statusCode != 200) {
      throw DriveException('Erreur d\'envoi Gmail : ${res.body}');
    }
    return (jsonDecode(res.body)['id'] as String?) ?? '';
  }
}
