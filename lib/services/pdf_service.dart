// Génération des PDF (porté depuis src/lib/plancheTraceePdf.ts,
// src/lib/lodgeHeader.ts, src/components/SessionsList.tsx -> generateConvocationPDF
// et src/lib/googleDrive.ts -> generateEmargementPdf).
//
// Trois documents sont produits, avec un rendu aligné sur la version React :
//  - la convocation / ordre du jour ;
//  - la feuille de présence / émargement (tableau membres + invités) ;
//  - la planche tracée (texte officiel de la tenue + signatures).
//
// Points clés de fidélité :
//  - toutes les longueurs sont exprimées en millimètres (comme jsPDF `unit:'mm'`)
//    via la constante `_mm` ; les tailles de police restent en points ;
//  - la convocation et la planche utilisent la police DejaVu Sans embarquée
//    (rendu identique des symboles maçonniques « ∴ »), exactement comme React ;
//  - la feuille de présence utilise une police à empattement (Times), comme React.
//
// Les signatures sont des data URLs base64 stockées dans `session.signatures`
// (et les champs planche* pour la planche tracée).
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import 'agape_payment_service.dart';

// 1 mm en points PDF (le paquet `pdf` travaille en points ; jsPDF en mm).
const double _mm = PdfPageFormat.mm;

const _navy = PdfColor.fromInt(0xFF0C235C);
const _violet = PdfColor.fromInt(0xFF701A75);
const _grey = PdfColor.fromInt(0xFFD9D9D9);
const _lodgeName = 'Bénou Ré';

// Placement rituel de chaque office dans le Temple.
const Map<String, String> _officePlacement = {
  'Trésorier': 'Orient',
  'Hospitalier': 'Orient',
  'Secrétaire': 'Orient',
  'Orateur': 'Orient',
  'Premier Surveillant': 'Colonne du Midi',
  '1er Surveillant': 'Colonne du Midi',
  'Second Surveillant': 'Colonne du Nord',
  '2nd Surveillant': 'Colonne du Nord',
  '2ème Surveillant': 'Colonne du Nord',
  'Expert': 'Colonne du Midi',
  'Maître des Cérémonies': 'Colonne du Nord',
  'Couvreur': 'Occident',
  'Maître des Banquets': 'Colonne du Midi',
  "Maître de l'Harmonie": 'Colonne du Nord',
  "Maître de la Colonne d'Harmonie": 'Colonne du Nord',
};

const Map<String, String> _directPlacement = {
  'à l’Orient': 'Orient',
  "à l'Orient": 'Orient',
  'Colonne du Septentrion': 'Colonne du Nord',
  'Colonne du midi': 'Colonne du Midi',
  'Colonne du Midi': 'Colonne du Midi',
};

String _degreOrdinal(String? degre) => Session.degreeOrdinal(degre ?? '');

String _formatDateFR(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'xx-xx-xxxx';
  final d = DateTime.tryParse(dateStr);
  if (d == null) return 'xx-xx-xxxx';
  return DateFormat('dd-MM-yyyy').format(d);
}

String _formatDateFrench(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'date inconnue';
  final d = DateTime.tryParse(dateStr);
  if (d == null) return 'date inconnue';
  return DateFormat('d MMMM y', 'fr_FR').format(d);
}

Uint8List? _decodeSignature(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final idx = dataUrl.indexOf('base64,');
  final b64 = idx >= 0 ? dataUrl.substring(idx + 7) : dataUrl;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

List<String> _collectOrdreDuJour(Session s) {
  final raw = <String?>[
    s.travail1,
    s.travail2,
    s.travail3,
    s.travail4,
    ...s.ordresJour.where((o) => o.trim().isNotEmpty),
    s.ligneCloture,
  ];
  final fallback = <String?>[s.agenda1, s.agenda2, s.agenda3, s.agenda4];
  final source = raw.any((r) => (r ?? '').trim().isNotEmpty) ? raw : fallback;
  return source
      .map(
        (item) =>
            (item ?? '').replaceFirst(RegExp(r'^\s*\d+\s*[.)]\s*'), '').trim(),
      )
      .where((item) => item.isNotEmpty)
      .toList();
}

// Calendrier égyptien du R∴A∴P∴M∴M∴ (porté depuis lodgeHeader.ts -> getMasonicDate).
const _egMonths = [
  ['THOT', 'SCHA'],
  ['PAOPHI', 'SCHA'],
  ['ATHYR', 'SCHA'],
  ['KHAOIAK', 'SCHA'],
  ['TYBI', 'PRE'],
  ['MEKHEIN', 'PRE'],
  ['PHAMENOTH', 'PRE'],
  ['PHARMOUTHI', 'PRE'],
  ['PAKHOUS', 'SCHEMON'],
  ['PSYRIE', 'SCHEMON'],
  ['EPIPHI', 'SCHEMON'],
  ['MESORI', 'SCHEMON'],
];
const _egEpagomenes = ['OSIRIS', 'HORUS', 'SETH', 'ISIS', 'NEPHTHYS'];

String getMasonicDate(DateTime? date) {
  if (date == null) return 'Date inconnue';
  final d = DateTime(date.year, date.month, date.day, 12);
  final civilYear = d.year;
  final newYear = DateTime(civilYear, 7, 19, 12);
  final DateTime start;
  final int egYear;
  if (!d.isBefore(newYear)) {
    start = newYear;
    egYear = civilYear + 1292;
  } else {
    start = DateTime(civilYear - 1, 7, 19, 12);
    egYear = civilYear - 1 + 1292;
  }
  final offset = d.difference(start).inDays;
  const suffixe = 'de la Lumière d’Égypte';
  if (offset >= 360) {
    final idx = (offset - 360).clamp(0, _egEpagomenes.length - 1);
    final ord = idx + 1;
    final ordStr = ord == 1
        ? '1er'
        : '$ord'
              'ème';
    return 'Le $ordStr jour épagomène (Naissance de ${_egEpagomenes[idx]}) De l’an $egYear $suffixe';
  }
  final monthIndex = (offset ~/ 30).clamp(0, _egMonths.length - 1);
  final dayInMonth = (offset % 30) + 1;
  final month = _egMonths[monthIndex];
  final dayStr = dayInMonth == 1
      ? '1er'
      : '$dayInMonth'
            'ème';
  return 'Le $dayStr jour du mois de ${month[0]} de la saison ${month[1]} De l’an $egYear $suffixe';
}

String _degreToOrdinalLong(String? degre) {
  switch (normalizeGrade(degre)) {
    case kCompagnon:
      return '2eme DEGRE';
    case kMaitre:
      return '3eme DEGRE';
    default:
      return '1er DEGRE';
  }
}

String _formatDateConvoc(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'xx-xx-xxxx';
  final d = DateTime.tryParse(dateStr);
  if (d == null) return 'xx-xx-xxxx';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(d);
}

class _PdfFonts {
  final pw.Font base;
  final pw.Font bold;
  _PdfFonts(this.base, this.bold);
}

// Police DejaVu Sans embarquée (identique à la version React : rend les « ∴ »).
Future<_PdfFonts> _loadLodgeFonts() async {
  final base = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  return _PdfFonts(base, bold);
}

// Feuille de présence : police à empattement (Times), comme le PDF React.
_PdfFonts _serifFonts() => _PdfFonts(pw.Font.times(), pw.Font.timesBold());

// En-tête commun des documents officiels (logos GLDB/Bénou Ré, GRANDE LOGE DE
// BOURBON, rites historiques, filiations, R∴L∴ Bénou Ré) — porté de
// lodgeHeader.ts -> drawLodgeHeader.
const _rites = [
  ['Rite Primitif', 'Paris 1721'],
  ['Rite Primitif des Philadelphes', 'Narbonne 1779'],
  ['Rite de Memphis', 'Montauban 1815'],
  ['Rite de Misraïm', 'Venise 1788'],
  ['Rite Ancien et Primitif', 'Manchester 1876'],
];
const _filiations = [
  'Filiation directe Robert Ambelain',
  'Filiation Directe Gérard Kloppel',
  'Filiation Directe Joseph Tsang Mang Kin',
];

pw.Widget _lodgeHeader(
  _PdfFonts fonts,
  pw.ImageProvider? logoGldb,
  pw.ImageProvider? logoBenou,
) {
  pw.Widget logoBox(pw.ImageProvider? img) => pw.SizedBox(
    width: 26 * _mm,
    height: 26 * _mm,
    child: img == null ? pw.SizedBox() : pw.Image(img, fit: pw.BoxFit.contain),
  );
  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          logoBox(logoGldb),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  'GRANDE LOGE DE BOURBON',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 16,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 2 * _mm),
                pw.Text(
                  'FRANCS-MAÇONS TRAVAILLANT AU RITE ANCIEN ET PRIMITIF DE MEMPHIS MISRAÏM',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.base, fontSize: 7.5),
                ),
              ],
            ),
          ),
          logoBox(logoBenou),
        ],
      ),
      pw.SizedBox(height: 8 * _mm),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final r in _rites)
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    r[0],
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fonts.bold, fontSize: 7.5),
                  ),
                  pw.SizedBox(height: 1 * _mm),
                  pw.Text(
                    r[1],
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fonts.base, fontSize: 7),
                  ),
                ],
              ),
            ),
        ],
      ),
      pw.SizedBox(height: 10 * _mm),
      for (final f in _filiations)
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 1 * _mm),
          child: pw.Text(
            f,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: fonts.base,
              fontSize: 8,
              color: const PdfColor.fromInt(0xFF505050),
            ),
          ),
        ),
      pw.SizedBox(height: 7 * _mm),
      pw.Text(
        'R∴ L∴ Bénou Ré N°5',
        style: pw.TextStyle(font: fonts.bold, fontSize: 15, color: _navy),
      ),
      pw.SizedBox(height: 2 * _mm),
      pw.Text(
        'O∴ de Saint Pierre – Île de la Réunion',
        style: pw.TextStyle(font: fonts.bold, fontSize: 11, color: _navy),
      ),
      pw.SizedBox(height: 12 * _mm),
    ],
  );
}

Future<List<pw.ImageProvider?>> _loadLogos() async {
  Future<pw.ImageProvider?> load(String path) async {
    try {
      return await imageFromAssetBundle(path);
    } catch (_) {
      return null;
    }
  }

  return Future.wait([load('assets/GLDB.png'), load('assets/Benou-Re.png')]);
}

// ══════════════════════════════════════════════════════════════════
// CONVOCATION / ORDRE DU JOUR
// ══════════════════════════════════════════════════════════════════
Future<Uint8List> buildConvocationPdf(Session session, int chrono) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();
  final doc = pw.Document();

  final dateSource = session.dateReprise ?? session.date;
  final dateFormatted = _formatDateConvoc(dateSource);
  final degreLong = _degreToOrdinalLong(session.degreTravail ?? session.degree);
  final typeTenue =
      session.typeTenue ??
      (session.type.isNotEmpty ? session.type : 'Ordinaire');
  final lieu =
      session.lieuReunionExtra ??
      (session.location.isNotEmpty
          ? session.location
          : 'Temple Thérèse Eliseman à Saint-Pierre');
  final masonicDate = getMasonicDate(DateTime.tryParse(dateSource));
  final items = _collectOrdreDuJour(session);
  final medaille = (session.montantMedaille ?? 0) > 0
      ? ' La médaille est de ${session.montantMedaille} euros.'
      : '';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(15 * _mm),
      build: (context) => [
        _lodgeHeader(fonts, logos[0], logos[1]),
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.4),
          ),
          padding: pw.EdgeInsets.symmetric(
            vertical: 3 * _mm,
            horizontal: 4 * _mm,
          ),
          child: pw.Text(
            'ORDRE DU JOUR DE LA TENUE RÉGULIÈRE DU ${dateFormatted.toUpperCase()} E∴V∴',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: fonts.bold, fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 12 * _mm),
        pw.Center(
          child: pw.Text(
            'A la Gloire Du Grand Architecte De l\'Univers,',
            style: pw.TextStyle(font: fonts.base, fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Center(
          child: pw.Text(
            'Mes TT∴CC∴SS∴ et TT∴CC∴FF∴,',
            style: pw.TextStyle(font: fonts.base, fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 9 * _mm),
        pw.Text(
          'La R∴L∴ Bénou Ré a la grande joie de vous convier fraternellement à participer aux Travaux de sa $chrono° TENUE ${typeTenue.toUpperCase()} au $degreLong qui se déroulera au $lieu le :',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.base, fontSize: 11, color: _violet),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Text(
          masonicDate,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 11, color: _navy),
        ),
        pw.SizedBox(height: 12 * _mm),
        pw.Text(
          "L'ordre du jour appellera :",
          style: pw.TextStyle(font: fonts.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 8 * _mm),
        for (var i = 0; i < items.length; i++)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 2.5 * _mm),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${i + 1}. ',
                  style: pw.TextStyle(font: fonts.base, fontSize: 11),
                ),
                pw.Expanded(
                  child: pw.Text(
                    items[i],
                    style: pw.TextStyle(font: fonts.base, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 12 * _mm),
        pw.Text(
          "Les Travaux seront suivis d'Agapes au nom de la Fraternité en Salle Humide.$medaille",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.base, fontSize: 10, color: _navy),
        ),
        pw.SizedBox(height: 3 * _mm),
        pw.Text(
          "Merci aux SS∴ et FF∴ Invités de s'annoncer afin d'ajuster au mieux les Agapes. Tél : 06 93 470 700",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.base, fontSize: 10, color: _navy),
        ),
      ],
    ),
  );

  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// FEUILLE DE PRÉSENCE / ÉMARGEMENT
// ══════════════════════════════════════════════════════════════════
Future<Uint8List> buildEmargementPdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
) async {
  final fonts = _serifFonts();
  // DejaVu en repli : Times (standard-14) ne connaît pas « – » ni certains
  // symboles ; on garde la typo Times avec repli DejaVu pour les glyphes manquants.
  final fallback = await _loadLodgeFonts();
  final logo = (await _loadLogos())[1]; // Bénou Ré
  final doc = pw.Document();

  final signatures = session.signatures;
  final type = session.type.isNotEmpty ? session.type : 'Ordinaire';
  final degree = session.degree.isNotEmpty ? session.degree : 'Apprenti';
  final sessionNumber =
      session.sessionNumber ??
      (session.chrono != null ? '${session.chrono}' : '');
  final location = session.location.isNotEmpty
      ? session.location
      : (session.lieuReunionExtra ?? '');
  final dateStr = session.date.isNotEmpty
      ? session.date
      : (session.dateReprise ?? '');

  final memberRows = members
      .where((m) => session.presentIds.contains(m.id))
      .map(
        (m) => _Row(
          m.lastName,
          m.firstName,
          m.function != 'Aucun' && m.function.isNotEmpty
              ? m.function
              : 'Membre',
          _lodgeName,
          signatures[m.id],
        ),
      )
      .toList();
  final visitorRows = visitors
      .where((v) => session.visitorIds.contains(v.id))
      .map(
        (v) => _Row(
          v.lastName,
          v.firstName,
          session.visitorRoles[v.id] ??
              (v.function.isNotEmpty ? v.function : 'Visiteur'),
          v.lodge,
          signatures[v.id],
        ),
      )
      .toList();

  pw.Widget header() => pw.Column(
    children: [
      if (logo != null)
        pw.Center(
          child: pw.SizedBox(
            height: 32 * _mm,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        ),
      pw.SizedBox(height: 4 * _mm),
      pw.Text(
        'Respectable Loge Benou Ré',
        style: pw.TextStyle(font: fonts.bold, fontSize: 18, color: _violet),
      ),
      pw.SizedBox(height: 3 * _mm),
      pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.4),
          ),
        ),
      ),
      pw.SizedBox(height: 10 * _mm),
      pw.Text(
        'FEUILLE DE PRÉSENCE',
        style: pw.TextStyle(
          font: fonts.bold,
          fontSize: 22,
          color: _violet,
          letterSpacing: 1,
        ),
      ),
      pw.SizedBox(height: 1 * _mm),
      pw.Container(
        width: 92 * _mm,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _violet, width: 1)),
        ),
      ),
      pw.SizedBox(height: 10 * _mm),
    ],
  );

  pw.Widget metaLine(String label, String value) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 2 * _mm),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: label,
            style: pw.TextStyle(font: fonts.bold, fontSize: 14),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(font: fonts.base, fontSize: 14),
          ),
        ],
      ),
    ),
  );

  pw.Table sectionTable(String label) => pw.Table(
    border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _grey),
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            height: 9 * _mm,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: fonts.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    ],
  );

  const headers = ['Nom', 'Prénom', 'Fonction', 'Loge', 'Signature'];
  final colWidths = {
    0: const pw.FlexColumnWidth(35),
    1: const pw.FlexColumnWidth(35),
    2: const pw.FlexColumnWidth(35),
    3: const pw.FlexColumnWidth(35),
    4: const pw.FlexColumnWidth(30),
  };

  pw.Table dataTable(List<_Row?> rows, double rowHeight) {
    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _grey),
          children: [
            for (final h in headers)
              pw.Container(
                alignment: pw.Alignment.center,
                height: 9 * _mm,
                child: pw.Text(
                  h,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 11),
                ),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              _cell(fonts, row?.lastName, rowHeight, maxLines: 2),
              _cell(fonts, row?.firstName, rowHeight, maxLines: 2),
              _cell(fonts, row?.role, rowHeight, maxLines: 2),
              _cell(fonts, row?.lodge, rowHeight, maxLines: 2),
              _signatureCell(_decodeSignature(row?.signature), rowHeight),
            ],
          ),
      ],
    );
  }

  final memberSlots = List<_Row?>.generate(
    20,
    (i) => i < memberRows.length ? memberRows[i] : null,
  );
  final visitorSlots = visitorRows;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(20 * _mm, 12 * _mm, 20 * _mm, 18 * _mm),
      theme: pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.bold,
        fontFallback: [fallback.base, fallback.bold],
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber}',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10),
        ),
      ),
      build: (context) => [
        header(),
        metaLine('Objet : ', "Tenue $type – Grade d'$degree"),
        metaLine('Fiche N° : ', sessionNumber),
        metaLine('Date : ', _formatDateFrench(dateStr)),
        metaLine('Lieu : ', location),
        pw.SizedBox(height: 8 * _mm),
        sectionTable('MEMBRES DE LA LOGE'),
        dataTable(memberSlots, 8 * _mm),
        pw.NewPage(),
        sectionTable('INVITÉS'),
        dataTable(visitorSlots, 8 * _mm),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _cell(
  _PdfFonts fonts,
  String? value,
  double minHeight, {
  int maxLines = 1,
}) => pw.Container(
  constraints: pw.BoxConstraints(minHeight: minHeight),
  alignment: pw.Alignment.centerLeft,
  padding: pw.EdgeInsets.symmetric(horizontal: 2 * _mm),
  child: pw.Text(
    value ?? '',
    softWrap: true,
    maxLines: maxLines,
    overflow: pw.TextOverflow.clip,
    style: pw.TextStyle(font: fonts.base, fontSize: 11),
  ),
);

pw.Widget _signatureCell(Uint8List? bytes, double minHeight) => pw.Container(
  constraints: pw.BoxConstraints(minHeight: minHeight),
  alignment: pw.Alignment.center,
  padding: pw.EdgeInsets.all(1 * _mm),
  child: bytes == null
      ? pw.SizedBox()
      : pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
);

// ══════════════════════════════════════════════════════════════════
// PAIEMENT DES AGAPES
// ══════════════════════════════════════════════════════════════════

/// Feuille de paiement des agapes : chaque payeur signe le règlement de sa
/// médaille, le total encaissé figure en bas du tableau.
Future<Uint8List> buildAgapePaymentPdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
) async {
  final fonts = await _loadLodgeFonts();
  final logo = (await _loadLogos())[1]; // Bénou Ré
  final doc = pw.Document();

  final payers = agapePayers(session, members, visitors);
  final signatures = session.agapePaymentSignatures;
  final amount = agapeMedailleAmount(session);
  final total = agapeCollectedTotal(session, members, visitors);
  final sessionNumber =
      session.sessionNumber ??
      (session.chrono != null ? '${session.chrono}' : '');
  final dateStr = session.date.isNotEmpty
      ? session.date
      : (session.dateReprise ?? '');

  const headers = [
    'Nom',
    'Prénom',
    'Obédience',
    'Loge',
    'Montant',
    'Signature',
  ];
  final colWidths = {
    0: const pw.FlexColumnWidth(26),
    1: const pw.FlexColumnWidth(22),
    2: const pw.FlexColumnWidth(18),
    3: const pw.FlexColumnWidth(46),
    4: const pw.FlexColumnWidth(16),
    5: const pw.FlexColumnWidth(30),
  };

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(18 * _mm, 12 * _mm, 18 * _mm, 18 * _mm),
      theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
      build: (context) => [
        if (logo != null)
          pw.Center(
            child: pw.SizedBox(
              height: 30 * _mm,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
        pw.SizedBox(height: 4 * _mm),
        pw.Center(
          child: pw.Text(
            'R∴ L∴ Bénou Ré N°5',
            style: pw.TextStyle(font: fonts.bold, fontSize: 15, color: _navy),
          ),
        ),
        pw.SizedBox(height: 8 * _mm),
        pw.Center(
          child: pw.Text(
            'PAIEMENT DES AGAPES',
            style: pw.TextStyle(
              font: fonts.bold,
              fontSize: 20,
              color: _violet,
              letterSpacing: 1,
            ),
          ),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Text(
          'Tenue N° $sessionNumber du ${_formatDateFrench(dateStr)}'
          ' — médaille : ${_formatAmount(amount)}',
          style: pw.TextStyle(font: fonts.base, fontSize: 12),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Table(
          columnWidths: colWidths,
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _grey),
              children: [
                for (final h in headers)
                  pw.Container(
                    alignment: pw.Alignment.center,
                    height: 9 * _mm,
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                    ),
                  ),
              ],
            ),
            for (final p in payers)
              pw.TableRow(
                children: [
                  _cell(fonts, p.lastName, 10 * _mm),
                  _cell(fonts, p.firstName, 10 * _mm),
                  _cell(fonts, p.obedience, 10 * _mm, maxLines: 2),
                  _cell(fonts, p.lodge, 10 * _mm, maxLines: 2),
                  _cell(fonts, _formatAmount(amount), 10 * _mm),
                  _signatureCell(_decodeSignature(signatures[p.id]), 10 * _mm),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total encaissé : ${_formatAmount(total)}',
            style: pw.TextStyle(font: fonts.bold, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

String _formatAmount(num value) {
  final s = value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');
  return '$s €';
}

class _Row {
  final String lastName;
  final String firstName;
  final String role;
  final String lodge;
  final String? signature;
  _Row(this.lastName, this.firstName, this.role, this.lodge, this.signature);
}

// ══════════════════════════════════════════════════════════════════
// PLANCHE TRACÉE
// ══════════════════════════════════════════════════════════════════

String _memberFullName(Member m) => '${m.firstName} ${m.lastName}'.trim();
String _visitorFullName(Visitor v) => '${v.firstName} ${v.lastName}'.trim();

/// Points de l'ordre du jour effectivement traités (utilisé par l'éditeur de
/// planche pour aligner les notes de travaux sur les points de l'ordre du jour).
List<String> plancheOrdreDuJour(Session session) =>
    _collectOrdreDuJour(session);

/// Nom du V∴M∴ : champ de la tenue, sinon nom enregistré dans
/// `config/settings`, sinon le membre portant l'office de Vénérable Maître.
String plancheVmName(
  Session session,
  List<Member> members, {
  String lodgeVmName = '',
}) {
  if (session.vmName?.isNotEmpty == true) return session.vmName!;
  if (lodgeVmName.trim().isNotEmpty) return lodgeVmName.trim();
  final vm = members
      .where((m) => foldLabel(m.function).contains('venerable'))
      .firstOrNull;
  return vm != null ? _memberFullName(vm) : 'Vénérable Maître';
}

/// Nom de l'Orateur retenu pour la planche : champ explicite, sinon Orateur
/// présent parmi les membres, sinon visiteur portant l'office d'Orateur.
String? plancheOrateurName(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
) {
  if (session.plancheOrateurName?.isNotEmpty == true) {
    return session.plancheOrateurName;
  }
  final member = members
      .where(
        (m) =>
            m.function.trim() == 'Orateur' && session.presentIds.contains(m.id),
      )
      .firstOrNull;
  if (member != null) return _memberFullName(member);
  final visitor = visitors
      .where(
        (v) =>
            session.visitorIds.contains(v.id) &&
            (session.visitorRoles[v.id] ?? v.function).trim() == 'Orateur',
      )
      .firstOrNull;
  return visitor != null ? _visitorFullName(visitor) : null;
}

/// Construit le texte intégral de la planche tracée (un paragraphe par ligne).
///
/// Cette fonction pure sert à la fois à pré-remplir l'éditeur de planche
/// (`PlancheTraceeEditScreen`) et à générer le corps du PDF lorsqu'aucun texte
/// n'a été enregistré dans `session.plancheDraftText`.
String buildPlancheTraceeText(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  int chrono, {
  num? troncAmount,
  String? sacPropositions,
  List<String>? travauxNotes,
  String lodgeVmName = '',
}) {
  final paras = <String>[];
  final vmName = plancheVmName(session, members, lodgeVmName: lodgeVmName);
  final dateFR = _formatDateFR(session.dateReprise ?? session.date);
  final degre = _degreOrdinal(session.degreTravail ?? session.degree);

  paras.add('Planche Tracée de la Tenue Régulière N°$chrono du $dateFR');
  paras.add('De la Respectable Loge BENOU RE N°5 à l’Orient Saint-Pierre');
  paras.add(
    'Vénérable Maître en chaire et vous tous mes Frères et Sœurs en vos grades et qualités.',
  );
  paras.add(
    'Protocole de la Tenue ${session.type == 'Solennelle' ? 'Solennelle' : (session.typeTenue ?? (session.type.isNotEmpty ? session.type : 'Régulière'))} du $dateFR de Ère Vulgaire.',
  );
  paras.add(
    'Les Membres composant la Respectable Loge BENOU RE N°5 régulièrement Convoqués, sont traditionnellement réunis en un lieu très pur, très saint et très éclairé par la lumière d’Egypte, lieu où règne la Paix, la Joie et l’Harmonie.',
  );
  paras.add(
    'Les Sœurs et Frères sont éclairés à l’orient par la sagesse du V∴ M∴ en chaire $vmName.',
  );
  paras.add(
    'Les Sœurs et Frères dont le nom figure sur le registre des présences, nous ont fait la joie d’assister à nos travaux.',
  );

  // Membres excusés
  final excused = session.excusedIds
      .map((id) => members.where((m) => m.id == id).firstOrNull)
      .whereType<Member>()
      .toList();
  if (excused.isNotEmpty) {
    final noms = excused.map(_memberFullName).join(', ');
    paras.add(
      '$noms membre(s) de la R∴ L∴ Bénou Ré sont absents excusés. (Voir la liste des membres excusés)',
    );
  } else {
    paras.add('Aucun membre de la R∴ L∴ Bénou Ré n’est absent excusé.');
  }

  // Invités
  final presentVisitors = session.visitorIds
      .map((id) => visitors.where((v) => v.id == id).firstOrNull)
      .whereType<Visitor>()
      .toList();

  String? roleOf(Visitor v) {
    final r = (session.visitorRoles[v.id] ?? '').trim();
    if (r.isNotEmpty && r != 'Simple Visiteur' && r != 'Visiteur') return r;
    final f = v.function.trim();
    if (f.isNotEmpty && f != 'Simple Visiteur' && f != 'Visiteur') return f;
    return null;
  }

  bool isOffice(String role) => _officePlacement.containsKey(role);
  String? placementOf(Visitor v) {
    final role = roleOf(v);
    if (role == null) return null;
    return _officePlacement[role] ?? _directPlacement[role];
  }

  String placementSentence(Visitor v, String placement, String role) {
    final who = 'le F∴ S∴ ${_visitorFullName(v)} (${v.lodge})';
    final qualite = isOffice(role) ? ' en qualité de $role' : '';
    switch (placement) {
      case 'Colonne du Midi':
        return 'Au Midi, a pris place $who$qualite.';
      case 'Colonne du Nord':
        return 'Au Nord, a pris place $who$qualite.';
      case 'Occident':
        return 'À l’Occident, à la porte d’entrée à l’intérieur, a pris place $who$qualite.';
      default:
        return 'À l’Orient, a pris place $who$qualite.';
    }
  }

  final dignitairesOrient = presentVisitors
      .where(
        (v) =>
            placementOf(v) == 'Orient' &&
            roleOf(v) != 'Orateur' &&
            isOffice(roleOf(v) ?? ''),
      )
      .toList();
  if (dignitairesOrient.isNotEmpty) {
    final liste = dignitairesOrient
        .map((v) => '${_visitorFullName(v)} (${roleOf(v)} – ${v.lodge})')
        .join(', ');
    paras.add(
      'A l’Orient, sont venus soutenir nos travaux les dignitaires suivants : $liste.',
    );
  }

  final orateurName = plancheOrateurName(session, members, visitors);
  paras.add(
    orateurName != null
        ? 'Le poste d’Orateur est occupé par le F∴ S∴ $orateurName.'
        : 'Le poste d’Orateur est resté vide.',
  );

  for (final v in presentVisitors) {
    final role = roleOf(v);
    final placement = placementOf(v);
    if (role == 'Orateur') continue;
    if (placement == 'Orient' && isOffice(role ?? '')) continue;
    if (placement != null) {
      paras.add(placementSentence(v, placement, role as String));
    } else {
      paras.add(
        'Le F∴ S∴ ${_visitorFullName(v)} (${v.lodge} – Orient de ${v.orient}) a pris place sur les Colonnes, selon la feuille de présence.',
      );
    }
  }

  paras.add('La planche tracée de nos derniers travaux a été adoptée.');

  // Ordre du jour traité
  paras.add('L’ordre du jour de la Tenue a appelé :');
  final items = _collectOrdreDuJour(session);
  final notes = travauxNotes ?? session.plancheTravauxNotes;
  for (var idx = 0; idx < items.length; idx++) {
    paras.add('${idx + 1}. ${items[idx]}');
    final note = (idx < notes.length ? notes[idx] : '').trim();
    if (note.isNotEmpty) paras.add(note);
  }

  // Tronc de la veuve et sac aux propositions
  paras.add(
    plancheTroncSentence(
      troncAmount ?? session.troncAmount,
      sacPropositions ?? session.sacPropositions ?? '',
    ),
  );

  paras.add(
    'Les Travaux sont ensuite fermés au $degre degré symbolique. Au cours de ce Cérémonial, les Sœurs et les Frères forment une Chaîne d’Union Fraternelle, selon le Rite, puis se séparent en jurant de garder le Silence sur les Travaux de ce Jour.',
  );
  paras.add('J’ai dit Vénérable Maître,');

  return paras.join('\n\n');
}

/// Phrase de clôture décrivant le Tronc de la Veuve et le Sac aux propositions.
String plancheTroncSentence(num troncAmount, String sacPropositions) {
  final tronc = troncAmount.toDouble();
  final euros = tronc.floor();
  final centimes = ((tronc - euros) * 100).round();
  final sac = sacPropositions.trim();
  return 'L’ordre du jour étant épuisé, le V∴ M∴ fait circuler le Tronc de la veuve '
      'et le Sac aux Propositions. '
      '${sac.isEmpty ? 'Ce dernier revient pur et sans tache.' : 'Sac aux Propositions : $sac'} '
      'Le Tronc revient lourd de $euros Pierre(s) Plate(s) et $centimes '
      'Morceau(x) d’éclats, qui ont été pris en charge par le Trésorier.';
}

/// Réécrit la phrase du Tronc/Sac dans un texte de planche déjà enregistré.
/// Les autres lignes sont conservées telles quelles et leur nombre est
/// inchangé, pour que les index des commentaires restent valides.
String plancheTextWithTronc(
  String body,
  num troncAmount,
  String sacPropositions,
) {
  final sentence = plancheTroncSentence(troncAmount, sacPropositions);
  final lines = body.split('\n');
  var found = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('Tronc revient lourd de')) {
      lines[i] = sentence;
      found = true;
    }
  }
  return found ? lines.join('\n') : body;
}

/// Découpe le texte de la planche en lignes non vides. Sert d'index commun à
/// l'éditeur et au PDF pour rattacher les commentaires à leur ligne.
List<String> plancheParagraphs(String body) =>
    body.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

/// Texte de la planche effectivement utilisé : le brouillon enregistré prime
/// sur le texte généré automatiquement.
String plancheBodyText(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  int chrono, {
  String lodgeVmName = '',
}) {
  final draft = (session.plancheDraftText ?? '').trim();
  return draft.isNotEmpty
      ? draft
      : buildPlancheTraceeText(
          session,
          members,
          visitors,
          chrono,
          lodgeVmName: lodgeVmName,
        );
}

Future<Uint8List> buildPlancheTraceePdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  int chrono, {
  String lodgeVmName = '',
}) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();
  final doc = pw.Document();

  final content = <pw.Widget>[];
  content.add(_lodgeHeader(fonts, logos[0], logos[1]));

  pw.Widget para(
    String text, {
    double size = 10,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black,
    double gap = 4,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: gap * _mm),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: bold ? fonts.bold : fonts.base,
          fontSize: size,
          color: color,
        ),
      ),
    );
  }

  // Le texte édité et enregistré par le Secrétaire / V∴M∴ prime sur le texte
  // généré automatiquement.
  final paragraphs = plancheParagraphs(
    plancheBodyText(
      session,
      members,
      visitors,
      chrono,
      lodgeVmName: lodgeVmName,
    ),
  );
  final comments = session.plancheLineComments;

  for (var i = 0; i < paragraphs.length; i++) {
    if (i == 0) {
      content.add(
        para(
          paragraphs[i],
          size: 13,
          bold: true,
          align: pw.TextAlign.center,
          color: _navy,
          gap: 2,
        ),
      );
    } else if (i == 1) {
      content.add(
        para(
          paragraphs[i],
          size: 11,
          bold: true,
          align: pw.TextAlign.center,
          color: _navy,
          gap: 8,
        ),
      );
    } else {
      content.add(para(paragraphs[i], size: 10, gap: 4));
    }
    final comment = (comments['$i'] ?? '').trim();
    if (comment.isNotEmpty) {
      content.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: 6 * _mm, bottom: 4 * _mm),
          child: pw.Text(
            '— $comment',
            style: pw.TextStyle(font: fonts.base, fontSize: 9.5, color: _navy),
          ),
        ),
      );
    }
  }

  // Signatures
  final orateurName = plancheOrateurName(session, members, visitors);
  final secretaryMember = members
      .where(
        (m) =>
            m.function.trim() == 'Secrétaire' &&
            session.presentIds.contains(m.id),
      )
      .firstOrNull;
  final secretaryName = secretaryMember != null
      ? _memberFullName(secretaryMember)
      : '';
  final sigs = <List<String?>>[
    ['Le Frère Orateur', orateurName, session.plancheOrateurSignature],
    [
      'Le Vénérable Maître',
      plancheVmName(session, members, lodgeVmName: lodgeVmName),
      session.plancheVMSignature,
    ],
    ['La Sœur Secrétaire', secretaryName, session.plancheSecretarySignature],
  ];
  content.add(pw.SizedBox(height: 6 * _mm));
  content.add(
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final s in sigs)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  s[0]!,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 9.5,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 3 * _mm),
                pw.SizedBox(
                  height: 18 * _mm,
                  child: _decodeSignature(s[2]) == null
                      ? pw.SizedBox()
                      : pw.Image(
                          pw.MemoryImage(_decodeSignature(s[2])!),
                          fit: pw.BoxFit.contain,
                        ),
                ),
                pw.SizedBox(height: 3 * _mm),
                pw.Text(
                  s[1] ?? '',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.base, fontSize: 9),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(15 * _mm),
      build: (context) => content,
    ),
  );

  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// BILAN DE TRÉSORERIE (cotisations d'une année)
// ══════════════════════════════════════════════════════════════════
Future<Uint8List> buildTreasuryReportPdf(int year, List<Member> members) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();
  final doc = pw.Document();

  String euros(num v) => '${v.toStringAsFixed(2)} €';

  pw.Widget cell(
    String text, {
    bool bold = false,
    PdfColor color = PdfColors.black,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) => pw.Container(
    alignment: align,
    padding: pw.EdgeInsets.symmetric(horizontal: 2 * _mm, vertical: 1.5 * _mm),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: bold ? fonts.bold : fonts.base,
        fontSize: 9,
        color: color,
      ),
    ),
  );

  pw.Widget line(String label, num value, PdfColor color) => pw.Column(
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(font: fonts.base, fontSize: 9, color: _navy),
      ),
      pw.SizedBox(height: 1 * _mm),
      pw.Text(
        euros(value),
        style: pw.TextStyle(font: fonts.bold, fontSize: 14, color: color),
      ),
    ],
  );

  num collected = 0;
  num pending = 0;
  final rows = <pw.TableRow>[];
  for (final m in members) {
    final d = m.duesFor(year);
    final exempt = m.isExemptFromDues;
    if (!exempt) {
      collected += d.totalCollected;
      pending += d.totalPending;
    }

    String amount(num dues, num done, bool paid) {
      if (exempt) return '—';
      if (dues <= 0) return '—';
      if (paid || done >= dues) return '${euros(dues)} (soldé)';
      if (done > 0) return '${euros(done)} / ${euros(dues)}';
      return '0,00 € / ${euros(dues)}';
    }

    rows.add(
      pw.TableRow(
        children: [
          cell(m.fullName.isNotEmpty ? m.fullName : '—'),
          cell(exempt ? '${m.status} (exonéré)' : m.status),
          cell(amount(d.lodgeDues, d.lodgeCollected, d.lodgeDuesPaid)),
          cell(amount(d.orderDues, d.orderCollected, d.orderDuesPaid)),
          cell(
            amount(d.elevationDues, d.elevationCollected, d.elevationDuesPaid),
          ),
          cell(
            exempt ? '—' : euros(d.totalPending),
            bold: !exempt && d.totalPending > 0,
            color: !exempt && d.totalPending > 0 ? _violet : PdfColors.black,
            align: pw.Alignment.centerRight,
          ),
        ],
      ),
    );
  }

  const headers = ['Membre', 'Statut', 'Loge', 'Ordre', 'Grades', 'Reste dû'];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(15 * _mm),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(font: fonts.base, fontSize: 9),
        ),
      ),
      build: (context) => [
        _lodgeHeader(fonts, logos[0], logos[1]),
        pw.Center(
          child: pw.Text(
            'BILAN DES COTISATIONS $year',
            style: pw.TextStyle(font: fonts.bold, fontSize: 15, color: _navy),
          ),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            line('TOTAL ENCAISSÉ', collected, _navy),
            line('À PERCEVOIR', pending, _violet),
          ],
        ),
        pw.SizedBox(height: 8 * _mm),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.4),
          columnWidths: {
            0: const pw.FlexColumnWidth(28),
            1: const pw.FlexColumnWidth(18),
            2: const pw.FlexColumnWidth(20),
            3: const pw.FlexColumnWidth(20),
            4: const pw.FlexColumnWidth(20),
            5: const pw.FlexColumnWidth(16),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _grey),
              children: [for (final h in headers) cell(h, bold: true)],
            ),
            ...rows,
          ],
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Text(
          'Les membres Honoraires ou En sommeil sont exonérés de cotisation et '
          'ne sont pas comptés dans les totaux.',
          style: pw.TextStyle(
            font: fonts.base,
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2 * _mm),
        pw.Text(
          'Édité le ${DateFormat('d MMMM y', 'fr_FR').format(DateTime.now())}',
          style: pw.TextStyle(
            font: fonts.base,
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
