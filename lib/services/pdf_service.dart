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

import '../config/lodge_config.dart';
import '../models/civilite.dart';
import '../models/dignitary.dart';
import '../models/external_session.dart';
import '../models/member.dart';
import '../models/member_event.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../utils/name_mask.dart';
import 'activity_report_service.dart';
import 'attendance_stats_service.dart';
import 'agape_payment_service.dart';
import 'treasury_document_service.dart'
    show capitationCallBody, quitusBody;

// 1 mm en points PDF (le paquet `pdf` travaille en points ; jsPDF en mm).
const double _mm = PdfPageFormat.mm;

const _navy = PdfColor.fromInt(0xFF0C235C);
const _violet = PdfColor.fromInt(0xFF701A75);
const _grey = PdfColor.fromInt(0xFFD9D9D9);

// Placement rituel de chaque office dans le Temple.
const Map<String, String> _officePlacement = {
  'Secrétaire': 'Orient',
  'Orateur': 'Orient',
  'Premier Surveillant': 'Colonne du Midi',
  '1er Surveillant': 'Colonne du Midi',
  'Trésorier': 'Colonne du Midi',
  'Expert': 'Colonne du Midi',
  'Maître des Banquets': 'Colonne du Midi',
  'Second Surveillant': 'Colonne du Nord',
  '2nd Surveillant': 'Colonne du Nord',
  '2ème Surveillant': 'Colonne du Nord',
  'Maître des Cérémonies': 'Colonne du Nord',
  'Hospitalier': 'Colonne du Nord',
  "Maître de l'Harmonie": 'Colonne du Nord',
  "Maître de la Colonne d'Harmonie": 'Colonne du Nord',
  'Couvreur': 'Occident',
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

// Calendrier égyptien du R∴A∴P∴M∴M∴ (système Robert Ambelain) : Nouvel An
// (1er Thot) le 29 août, précédé des 5 jours Épagomènes (24-28 août), puis 12
// mois de 30 jours exacts chaînés depuis Thot. Voir
// consigne_calendrier_ambelain.txt (fourni par l'utilisateur) pour la
// spécification complète — remplace l'ancien calcul (Nouvel An au 19
// juillet, noms de mois erronés) porté depuis lodgeHeader.ts.
//
// Chaînage depuis Thot plutôt que dates de calendrier fixes par mois : la
// table « fixe alexandrine » donnée en référence associe à chaque mois une
// date de début figée (ex. Pharmouthi = 27 mars chaque année), mais un
// jour bissextile (29 février) s'intercale alors entre deux dates fixes
// distantes de piste exactement 30 jours en année non bissextile,
// laissant un jour orphelin (ex. 26 mars 2028) que ni l'un ni l'autre mois
// ne couvre. Chaîner 12 blocs de 30 jours depuis le seul point fixe (29
// août) élimine ce trou : les mois restent tous des multiples exacts de 30
// jours et ne dérivent que d'un jour, après un 29 février, par rapport aux
// dates de calendrier de la table de référence.
const _egMonths = [
  'Thot',
  'Paophi',
  'Athyr',
  'Khoiak',
  'Tybi',
  'Mekhir',
  'Phamenoth',
  'Pharmouthi',
  'Pakhons',
  'Payni',
  'Epiphi',
  'Mesori',
];
const _egEpagomenes = [
  'Naissance d’Osiris',
  'Naissance d’Horus',
  'Naissance de Seth',
  'Naissance d’Isis',
  'Naissance de Nephthys',
];

String getMasonicDate(DateTime? date) {
  if (date == null) return 'Date inconnue';
  final d = DateTime(date.year, date.month, date.day, 12);
  const suffixe = 'A.E.';
  String ordinal(int n) => n == 1 ? '1er' : '$nème';

  if (d.month == 8 && d.day >= 24 && d.day <= 28) {
    final idx = d.day - 24;
    final egYear = d.year + 1291;
    return 'Le ${ordinal(idx + 1)} jour Épagomène (${_egEpagomenes[idx]}) '
        'de l’An $egYear $suffixe';
  }

  final beforeNewYear = d.month < 8 || (d.month == 8 && d.day < 24);
  final egYear = d.year + (beforeNewYear ? 1291 : 1292);
  final thotStart = beforeNewYear
      ? DateTime(d.year - 1, 8, 29, 12)
      : DateTime(d.year, 8, 29, 12);
  final offset = d.difference(thotStart).inDays;
  final monthIndex = (offset ~/ 30).clamp(0, _egMonths.length - 1);
  final dayInMonth = (offset % 30) + 1;
  return 'Le ${ordinal(dayInMonth)} jour du mois de ${_egMonths[monthIndex]} '
      'de l’An $egYear $suffixe';
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

// En-tête commun des documents officiels (logos de l'obédience et de la Loge,
// GRANDE LOGE DE BOURBON, rites historiques, filiations, titre de la Loge) —
// porté de lodgeHeader.ts -> drawLodgeHeader.
//
// Les rites et les filiations sont ceux du R∴A∴P∴M∴M∴ : communs à toutes les
// loges de l'obédience, ils ne relèvent donc pas de LodgeConfig.
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
  pw.ImageProvider? logoBenou, {
  double scale = 1.0,
}) {
  final stacked = LodgeConfig.current.pdfHeaderStacked;
  pw.Widget logoBox(pw.ImageProvider? img) => pw.SizedBox(
    width: 26 * _mm * scale,
    height: 26 * _mm * scale,
    child: img == null ? pw.SizedBox() : pw.Image(img, fit: pw.BoxFit.contain),
  );

  final gldbTitle = [
    pw.Text(
      'GRANDE LOGE DE BOURBON',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.bold, fontSize: 16 * scale, color: _navy),
    ),
    pw.SizedBox(height: 2 * _mm * scale),
    pw.Text(
      'FRANCS-MAÇONS TRAVAILLANT AU RITE ANCIEN ET PRIMITIF DE MEMPHIS MISRAÏM',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.base, fontSize: 7.5 * scale),
    ),
  ];

  final lodgeTitle = [
    pw.Text(
      LodgeConfig.current.shortTitle,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.bold, fontSize: 15 * scale, color: _navy),
    ),
    pw.SizedBox(height: 2 * _mm * scale),
    pw.Text(
      'O∴ de ${LodgeConfig.current.orientLong}',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.bold, fontSize: 11 * scale, color: _navy),
    ),
  ];

  final ritesRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final r in _rites)
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                r[0],
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fonts.bold, fontSize: 7.5 * scale),
              ),
              pw.SizedBox(height: 1 * _mm * scale),
              pw.Text(
                r[1],
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fonts.base, fontSize: 7 * scale),
              ),
            ],
          ),
        ),
    ],
  );

  final filiationsBlock = [
    for (final f in _filiations)
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 1 * _mm * scale),
        child: pw.Text(
          f,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: fonts.base,
            fontSize: 8 * scale,
            color: const PdfColor.fromInt(0xFF505050),
          ),
        ),
      ),
  ];

  if (stacked) {
    // Les deux logos empilés dans une colonne fixe à gauche (GLDB puis
    // Loge), le reste du contenu (titre GLDB, rites, filiations) dans la
    // colonne restante à droite ; le titre de la loge vient ensuite, seul,
    // centré sur toute la largeur.
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              children: [
                logoBox(logoGldb),
                pw.SizedBox(height: 3 * _mm * scale),
                logoBox(logoBenou),
              ],
            ),
            pw.SizedBox(width: 4 * _mm * scale),
            pw.Expanded(
              child: pw.Column(
                children: [
                  ...gldbTitle,
                  pw.SizedBox(height: 8 * _mm * scale),
                  ritesRow,
                  pw.SizedBox(height: 10 * _mm * scale),
                  ...filiationsBlock,
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6 * _mm * scale),
        pw.Column(children: lodgeTitle),
        pw.SizedBox(height: 8 * _mm * scale),
      ],
    );
  }

  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          logoBox(logoGldb),
          pw.Expanded(child: pw.Column(children: gldbTitle)),
          logoBox(logoBenou),
        ],
      ),
      pw.SizedBox(height: 8 * _mm * scale),
      ritesRow,
      pw.SizedBox(height: 10 * _mm * scale),
      ...filiationsBlock,
      pw.SizedBox(height: 7 * _mm * scale),
      pw.Column(children: lodgeTitle),
      pw.SizedBox(height: 12 * _mm * scale),
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

  final lodge = LodgeConfig.current;
  return Future.wait([
    load(lodge.obedienceLogoAsset),
    load(lodge.lodgeLogoAsset),
  ]);
}

// ══════════════════════════════════════════════════════════════════
// CONVOCATION / ORDRE DU JOUR
// ══════════════════════════════════════════════════════════════════
// Échelle minimale acceptée avant d'abandonner la réduction : en dessous, le
// texte deviendrait difficilement lisible. Couvre tout ordre du jour
// raisonnable ; un cas extrême resterait sur une page mais très resserré.
const double _kConvocationMinScale = 0.55;
const double _kConvocationScaleStep = 0.05;

List<pw.Widget> _convocationContent({
  required _PdfFonts fonts,
  required List<pw.ImageProvider?> logos,
  required String dateFormatted,
  required String degreLong,
  required String typeTenue,
  required String lieu,
  required int chrono,
  required String masonicDate,
  required List<String> items,
  required String medaille,
  required String agapeDetails,
  required String accueilHeure,
  required String vmName,
  required String secretaryCivilite,
  required String secretaryName,
  required String telSuffix,
  required double scale,
}) {
  return [
    _lodgeHeader(fonts, logos[0], logos[1], scale: scale),
    pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.4),
      ),
      padding: pw.EdgeInsets.symmetric(
        vertical: 3 * _mm * scale,
        horizontal: 4 * _mm,
      ),
      child: pw.Text(
        'ORDRE DU JOUR DE LA TENUE RÉGULIÈRE DU ${dateFormatted.toUpperCase()} E∴V∴',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: fonts.bold, fontSize: 11 * scale),
      ),
    ),
    pw.SizedBox(height: 12 * _mm * scale),
    pw.Center(
      child: pw.Text(
        'A la Gloire Du Grand Architecte De l\'Univers,',
        style: pw.TextStyle(font: fonts.base, fontSize: 11 * scale),
      ),
    ),
    pw.SizedBox(height: 6 * _mm * scale),
    pw.Center(
      child: pw.Text(
        'Mes TT∴CC∴SS∴ et TT∴CC∴FF∴,',
        style: pw.TextStyle(font: fonts.base, fontSize: 11 * scale),
      ),
    ),
    pw.SizedBox(height: 9 * _mm * scale),
    pw.Text(
      'La R∴L∴ ${LodgeConfig.current.name} a la grande joie de vous convier fraternellement à participer aux Travaux de sa $chrono° TENUE ${typeTenue.toUpperCase()} au $degreLong qui se déroulera au $lieu :',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.base, fontSize: 11 * scale, color: _violet),
    ),
    pw.SizedBox(height: 6 * _mm * scale),
    pw.Text(
      masonicDate,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.bold, fontSize: 11 * scale, color: _navy),
    ),
    pw.SizedBox(height: 12 * _mm * scale),
    pw.Text(
      "L'ordre du jour appellera :",
      style: pw.TextStyle(font: fonts.bold, fontSize: 12 * scale),
    ),
    pw.SizedBox(height: 8 * _mm * scale),
    for (var i = 0; i < items.length; i++)
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 2.5 * _mm * scale),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${i + 1}. ',
              style: pw.TextStyle(font: fonts.base, fontSize: 11 * scale),
            ),
            pw.Expanded(
              child: pw.Text(
                items[i],
                style: pw.TextStyle(font: fonts.base, fontSize: 11 * scale),
              ),
            ),
          ],
        ),
      ),
    pw.SizedBox(height: 12 * _mm * scale),
    pw.Text(
      "Je remercie tous les FF∴ et SS∴ apprentis d'arriver à $accueilHeure pour "
      "aider à la mise en place du Temple sous la houlette du Maître Second "
      "Surveillant et du Maître Expert.",
      textAlign: pw.TextAlign.left,
      style: pw.TextStyle(font: fonts.base, fontSize: 10 * scale, color: _navy),
    ),
    pw.SizedBox(height: 6 * _mm * scale),
    pw.Text(
      "Les Travaux seront suivis d'Agapes fraternelles en Salle Humide$agapeDetails.$medaille",
      textAlign: pw.TextAlign.center,
      maxLines: 1,
      style: pw.TextStyle(font: fonts.base, fontSize: 9 * scale, color: _navy),
    ),
    pw.SizedBox(height: 3 * _mm * scale),
    pw.Text(
      "Merci aux SS∴ et FF∴ De s'annoncer afin d'ajuster au mieux les Agapes.$telSuffix",
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.base, fontSize: 8.5 * scale, color: _navy),
    ),
    pw.SizedBox(height: 8 * _mm * scale),
    pw.Text(
      'Par mandatement du V∴M∴ $vmName',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.base, fontSize: 10 * scale, color: _navy),
    ),
    pw.SizedBox(height: 2 * _mm * scale),
    pw.Text(
      'Le $secretaryCivilite Sec∴ $secretaryName',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: fonts.base, fontSize: 10 * scale, color: _navy),
    ),
  ];
}

/// Heure d'accueil des apprentis : une heure avant la reprise des travaux.
/// Repli « xxhxx » si l'heure de reprise n'est pas renseignée (même
/// convention que le premier travail généré par défaut).
String _heureMoinsUne(String dateSource) {
  final dt = DateTime.tryParse(dateSource);
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) return 'xxhxx';
  final before = dt.subtract(const Duration(hours: 1));
  return '${before.hour.toString().padLeft(2, '0')}h${before.minute.toString().padLeft(2, '0')}';
}

/// Heure d'accueil des apprentis d'une tenue (voir [_heureMoinsUne]),
/// exposée pour le texte de convocation par lien (invitation_service.dart).
String accueilApprentisHeure(Session session) =>
    _heureMoinsUne(session.dateReprise ?? session.date);

/// Numéro local sans indicatif ni espaces (ex. « +262 6 93 47 07 00 » ->
/// « 0693470700 ») — plus court à l'affichage qu'un numéro international
/// complet, sur une ligne de convocation déjà chargée.
String _localPhone(String raw) {
  var s = raw.replaceAll(' ', '');
  if (s.startsWith('+262')) s = '0${s.substring(4)}';
  return s;
}

Future<Uint8List> buildConvocationPdf(
  Session session,
  int chrono,
  List<Member> members, {
  String lodgeVmName = '',
}) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();

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
          : LodgeConfig.current.defaultMeetingPlace);
  final masonicDate = getMasonicDate(DateTime.tryParse(dateSource));
  final items = _collectOrdreDuJour(session);
  final medaille = (session.montantMedaille ?? 0) > 0
      ? ' La médaille est de ${session.montantMedaille} euros.'
      : '';
  final agapeHeure = (session.heureAgape ?? session.agapeTime).trim();
  final agapeType = (session.typeRepas ?? session.agapeType).trim();
  final agapeDetailsParts = [
    if (agapeHeure.isNotEmpty) 'à $agapeHeure',
    if (agapeType.isNotEmpty) '($agapeType)',
  ];
  final agapeDetails = agapeDetailsParts.isEmpty
      ? ''
      : ' ${agapeDetailsParts.join(' ')}';
  final accueilHeure = _heureMoinsUne(dateSource);
  final vmName = maskPersonName(
    plancheVmName(session, members, lodgeVmName: lodgeVmName),
  );
  final secretary = members
      .where((m) => foldLabel(m.function).contains('secretaire'))
      .firstOrNull;
  final secretaryName = secretary != null
      ? maskPersonName(_memberFullName(secretary))
      : 'Secrétaire';
  final secretaryCivilite = civiliteAbbrev(secretary?.civilite ?? '');
  final secretaryPhone = secretary?.phone.trim() ?? '';
  final vmMember = members
      .where((m) => foldLabel(m.function).contains('venerable'))
      .firstOrNull;
  final vmPhone = vmMember?.phone.trim() ?? '';
  final secretaryTitle = civiliteArticleAbbrev(
    secretary?.civilite ?? '',
    capitalize: true,
  );
  final telParts = [
    if (vmPhone.isNotEmpty) 'V∴M∴ : ${_localPhone(vmPhone)}',
    if (secretaryPhone.isNotEmpty)
      '$secretaryTitle Sec∴ : ${_localPhone(secretaryPhone)}',
  ];
  final telSuffix = telParts.isEmpty ? '' : ' Tél ${telParts.join(' — ')}';

  // Contrainte "une seule page, toujours" : on tente à pleine échelle, puis on
  // réduit progressivement police/interlignage/marges/logos jusqu'à ce que le
  // contenu tienne, plutôt que de laisser jsPDF/le moteur de mise en page
  // déborder sur une 2e page. Le contenu affiché n'est jamais retiré.
  var scale = 1.0;
  pw.Document doc;
  while (true) {
    doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15 * _mm * scale),
        build: (context) => _convocationContent(
          fonts: fonts,
          logos: logos,
          dateFormatted: dateFormatted,
          degreLong: degreLong,
          typeTenue: typeTenue,
          lieu: lieu,
          chrono: chrono,
          masonicDate: masonicDate,
          items: items,
          medaille: medaille,
          agapeDetails: agapeDetails,
          accueilHeure: accueilHeure,
          vmName: vmName,
          secretaryCivilite: secretaryCivilite,
          secretaryName: secretaryName,
          telSuffix: telSuffix,
          scale: scale,
        ),
      ),
    );
    final fitsOnePage = doc.document.pdfPageList.pages.length <= 1;
    if (fitsOnePage || scale <= _kConvocationMinScale) {
      break;
    }
    scale = (scale - _kConvocationScaleStep).clamp(
      _kConvocationMinScale,
      1.0,
    );
  }

  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// FEUILLE DE PRÉSENCE / ÉMARGEMENT
// ══════════════════════════════════════════════════════════════════
Future<Uint8List> buildEmargementPdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) async {
  final fonts = _serifFonts();
  // DejaVu en repli : Times (standard-14) ne connaît pas « – » ni certains
  // symboles ; on garde la typo Times avec repli DejaVu pour les glyphes manquants.
  final fallback = await _loadLodgeFonts();
  final logo = (await _loadLogos())[1]; // logo de la Loge
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
          maskPersonName(m.lastName),
          maskPersonName(m.firstName),
          m.function != 'Aucun' && m.function.isNotEmpty
              ? m.function
              : 'Membre',
          LodgeConfig.current.name,
          signatures[m.id],
        ),
      )
      .toList();
  final visitorRows = visitors
      .where((v) => session.visitorIds.contains(v.id))
      .map(
        (v) => _Row(
          maskPersonName(v.lastName),
          maskPersonName(v.firstName),
          session.visitorRoles[v.id] ??
              (v.function.isNotEmpty ? v.function : 'Visiteur'),
          v.lodge,
          signatures[v.id],
        ),
      )
      .toList();
  final dignitaryRows = dignitaries
      .where((d) => session.dignitaryIds.contains(d.id))
      .map(
        (d) => _Row(
          maskPersonName(d.lastName),
          maskPersonName(d.firstName),
          session.dignitaryRoles[d.id] ??
              (d.title.isNotEmpty ? d.title : 'Dignitaire'),
          d.lodge,
          signatures[d.id],
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
        'Respectable Loge ${LodgeConfig.current.name}',
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
  final dignitarySlots = dignitaryRows;

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
        if (dignitarySlots.isNotEmpty) ...[
          pw.NewPage(),
          sectionTable('DIGNITAIRES'),
          dataTable(dignitarySlots, 8 * _mm),
        ],
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
  List<Dignitary> dignitaries,
) async {
  final fonts = await _loadLodgeFonts();
  final logo = (await _loadLogos())[1]; // logo de la Loge
  final doc = pw.Document();

  final payers = agapePayers(session, members, visitors, dignitaries);
  final signatures = session.agapePaymentSignatures;
  final amount = agapeMedailleAmount(session);
  final total = agapeCollectedTotal(session, members, visitors, dignitaries);
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
            LodgeConfig.current.shortTitle,
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
                  _cell(fonts, maskPersonName(p.lastName), 10 * _mm),
                  _cell(fonts, maskPersonName(p.firstName), 10 * _mm),
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
///
/// Retourne le nom réel, non masqué : cette fonction alimente aussi l'écran
/// de signature (émargement), où le nom complet reste nécessaire. Les
/// appelants qui écrivent dans un document PDF doivent appliquer
/// [maskPersonName] eux-mêmes sur le résultat.
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
/// présent parmi les membres, sinon visiteur ou dignitaire portant l'office
/// d'Orateur.
String? plancheOrateurName(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) {
  if (session.plancheOrateurName?.isNotEmpty == true) {
    return maskPersonName(session.plancheOrateurName!);
  }
  final member = members
      .where(
        (m) =>
            m.function.trim() == 'Orateur' && session.presentIds.contains(m.id),
      )
      .firstOrNull;
  if (member != null) return maskPersonName(_memberFullName(member));
  final visitor = visitors
      .where(
        (v) =>
            session.visitorIds.contains(v.id) &&
            (session.visitorRoles[v.id] ?? v.function).trim() == 'Orateur',
      )
      .firstOrNull;
  if (visitor != null) return maskPersonName(_visitorFullName(visitor));
  final dignitary = dignitaries
      .where(
        (d) =>
            session.dignitaryIds.contains(d.id) &&
            (session.dignitaryRoles[d.id] ?? '').trim() == 'Orateur',
      )
      .firstOrNull;
  return dignitary != null ? maskPersonName(dignitary.fullName) : null;
}

/// Civilité de l'Orateur retenu, avec la même résolution que
/// [plancheOrateurName] (membre, sinon visiteur, sinon dignitaire). Vide si
/// le nom vient du champ saisi à la main (aucune fiche associée) ou si la
/// personne retrouvée n'a pas de civilité renseignée.
String _orateurCivilite(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) {
  if (session.plancheOrateurName?.isNotEmpty == true) return '';
  final member = members
      .where(
        (m) =>
            m.function.trim() == 'Orateur' && session.presentIds.contains(m.id),
      )
      .firstOrNull;
  if (member != null) return member.civilite;
  final visitor = visitors
      .where(
        (v) =>
            session.visitorIds.contains(v.id) &&
            (session.visitorRoles[v.id] ?? v.function).trim() == 'Orateur',
      )
      .firstOrNull;
  if (visitor != null) return visitor.civilite;
  final dignitary = dignitaries
      .where(
        (d) =>
            session.dignitaryIds.contains(d.id) &&
            (session.dignitaryRoles[d.id] ?? '').trim() == 'Orateur',
      )
      .firstOrNull;
  return dignitary?.civilite ?? '';
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
  List<Dignitary> dignitaries,
  int chrono, {
  num? troncAmount,
  String? sacPropositions,
  List<String>? travauxNotes,
  String lodgeVmName = '',
}) {
  final paras = <String>[];
  final vmName = maskPersonName(
    plancheVmName(session, members, lodgeVmName: lodgeVmName),
  );
  final dateFR = _formatDateFR(session.dateReprise ?? session.date);
  final degre = _degreOrdinal(session.degreTravail ?? session.degree);

  paras.add('Planche Tracée de la Tenue Régulière N°$chrono du $dateFR');
  final lodge = LodgeConfig.current;
  paras.add('De la ${lodge.formalTitleUpper} à l’Orient ${lodge.orient}');
  paras.add(
    'Vénérable Maître en chaire et vous tous mes Frères et Sœurs en vos grades et qualités.',
  );
  paras.add(
    'Protocole de la Tenue ${session.type == 'Solennelle' ? 'Solennelle' : (session.typeTenue ?? (session.type.isNotEmpty ? session.type : 'Régulière'))} du $dateFR de Ère Vulgaire.',
  );
  paras.add(
    'Les Membres composant la ${lodge.formalTitleUpper} régulièrement Convoqués, sont traditionnellement réunis en un lieu très pur, très saint et très éclairé par la lumière d’Egypte, lieu où règne la Paix, la Joie et l’Harmonie.',
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
    final noms = excused
        .mapIndexed(
          (i, m) =>
              '${civiliteArticleAbbrev(m.civilite, capitalize: i == 0)} '
              '${maskPersonName(_memberFullName(m))}',
        )
        .join(', ');
    paras.add(
      '$noms membre(s) de la R∴ L∴ ${lodge.name} sont absents excusés. (Voir la liste des membres excusés)',
    );
  } else {
    paras.add('Aucun membre de la R∴ L∴ ${lodge.name} n’est absent excusé.');
  }

  // Invités
  final presentVisitors = session.visitorIds
      .map((id) => visitors.where((v) => v.id == id).firstOrNull)
      .whereType<Visitor>()
      .toList();
  final presentDignitaries = session.dignitaryIds
      .map((id) => dignitaries.where((d) => d.id == id).firstOrNull)
      .whereType<Dignitary>()
      .toList();

  String? roleOf(Visitor v) {
    final r = (session.visitorRoles[v.id] ?? '').trim();
    if (r.isNotEmpty && r != 'Simple Visiteur' && r != 'Visiteur') return r;
    final f = v.function.trim();
    if (f.isNotEmpty && f != 'Simple Visiteur' && f != 'Visiteur') return f;
    return null;
  }

  // Un dignitaire n'a pas d'équivalent à `function` (identité par défaut) :
  // seul l'office éventuellement pris pendant cette tenue le distingue.
  String? roleOfDignitary(Dignitary d) {
    final r = (session.dignitaryRoles[d.id] ?? '').trim();
    return r.isEmpty ? null : r;
  }

  bool isOffice(String role) => _officePlacement.containsKey(role);
  String? placementOf(Visitor v) {
    final role = roleOf(v);
    if (role == null) return null;
    return _officePlacement[role] ?? _directPlacement[role];
  }

  // Sans office pris ce jour, un dignitaire n'est pas cité dans la planche
  // tracée (certains ne souhaitent pas y apparaître) : pas de repli par
  // défaut à l'Orient.
  String? placementOfDignitary(Dignitary d) {
    final role = roleOfDignitary(d);
    if (role == null) return null;
    return _officePlacement[role] ?? _directPlacement[role];
  }

  String placementSentence(Visitor v, String placement, String role) {
    final who =
        '${civiliteArticleAbbrev(v.civilite)} ${maskPersonName(_visitorFullName(v))} (${v.lodge})';
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

  String placementSentenceDignitary(Dignitary d, String placement, String role) {
    final lodgePart = d.lodge.isNotEmpty ? ' (${d.lodge})' : '';
    final who =
        '${civiliteArticleAbbrev(d.civilite)} ${maskPersonName(d.fullName)}$lodgePart';
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

  // Phrase collective des dignitaires à l'Orient : visiteurs ayant pris un
  // office qui y siège (comportement historique, inchangé) et, désormais,
  // les dignitaires présents — avec leur office s'ils en ont pris un, sinon
  // leur titre.
  final visitorOrientEntries = presentVisitors
      .where(
        (v) =>
            placementOf(v) == 'Orient' &&
            roleOf(v) != 'Orateur' &&
            isOffice(roleOf(v) ?? ''),
      )
      .map((v) => '${maskPersonName(_visitorFullName(v))} (${roleOf(v)} – ${v.lodge})');
  final dignitaryOrientEntries = presentDignitaries
      .where(
        (d) =>
            placementOfDignitary(d) == 'Orient' && roleOfDignitary(d) != 'Orateur',
      )
      .map((d) {
        final role = roleOfDignitary(d);
        final qualifier = (role != null && isOffice(role))
            ? role
            : (d.title.isNotEmpty ? d.title : 'Dignitaire');
        final lodgePart = d.lodge.isNotEmpty ? ' – ${d.lodge}' : '';
        return '${maskPersonName(d.fullName)} ($qualifier$lodgePart)';
      });
  final orientEntries = [...visitorOrientEntries, ...dignitaryOrientEntries];
  if (orientEntries.isNotEmpty) {
    paras.add(
      'A l’Orient, sont venus soutenir nos travaux les dignitaires suivants : ${orientEntries.join(', ')}.',
    );
  }

  final orateurName = plancheOrateurName(session, members, visitors, dignitaries);
  final orateurCivilite = _orateurCivilite(session, members, visitors, dignitaries);
  paras.add(
    orateurName != null
        ? 'Le poste d’Orateur est occupé par ${civiliteArticleAbbrev(orateurCivilite)} $orateurName.'
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
        '${civiliteArticleAbbrev(v.civilite, capitalize: true)} ${maskPersonName(_visitorFullName(v))} (${v.lodge} – Orient de ${v.orient}) a pris place sur les Colonnes, selon la feuille de présence.',
      );
    }
  }

  // Dignitaires ayant pris un office hors Orient (ceux à l'Orient sont déjà
  // couverts par la phrase collective ci-dessus ; ceux sans office pris ne
  // sont pas cités du tout).
  for (final d in presentDignitaries) {
    final role = roleOfDignitary(d);
    if (role == null || role == 'Orateur') continue;
    final placement = placementOfDignitary(d);
    if (placement == null || placement == 'Orient') continue;
    paras.add(placementSentenceDignitary(d, placement, role));
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
  List<Dignitary> dignitaries,
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
          dignitaries,
          chrono,
          lodgeVmName: lodgeVmName,
        );
}

Future<Uint8List> buildPlancheTraceePdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
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
      dignitaries,
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
  final orateurName = plancheOrateurName(session, members, visitors, dignitaries);
  final secretaryMember = members
      .where(
        (m) =>
            m.function.trim() == 'Secrétaire' &&
            session.presentIds.contains(m.id),
      )
      .firstOrNull;
  final secretaryName = secretaryMember != null
      ? maskPersonName(_memberFullName(secretaryMember))
      : '';
  final orateurCivilite = _orateurCivilite(session, members, visitors, dignitaries);
  final sigs = <List<String?>>[
    [
      '${civiliteTitle(orateurCivilite)} Orateur',
      orateurName,
      session.plancheOrateurSignature,
    ],
    [
      'Le Vénérable Maître',
      maskPersonName(plancheVmName(session, members, lodgeVmName: lodgeVmName)),
      session.plancheVMSignature,
    ],
    [
      '${civiliteTitle(secretaryMember?.civilite ?? '')} Secrétaire',
      secretaryName,
      session.plancheSecretarySignature,
    ],
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
          cell(m.fullName.isNotEmpty ? maskPersonName(m.fullName) : '—'),
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

// ══════════════════════════════════════════════════════════════════
// APPEL DE COTISATION / QUITUS — courrier individuel au membre
// ══════════════════════════════════════════════════════════════════

/// Lettre simple (en-tête + titre + corps sur des paragraphes) : le texte
/// vient de treasury_document_service.dart, partagé avec le corps du mail.
Future<Uint8List> _buildTreasuryLetterPdf(String title, String body) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(18 * _mm),
      build: (context) => [
        // Document de Trésorerie (monde profane, association loi 1901) :
        // pas de logo d'obédience — seul celui de la Loge est affiché, à la
        // place laissée par le logo GLDB (voir _lodgeHeader : premier
        // argument = position gauche).
        _lodgeHeader(fonts, logos[1], null),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(font: fonts.bold, fontSize: 14, color: _navy),
          ),
        ),
        pw.SizedBox(height: 8 * _mm),
        for (final line in body.split('\n'))
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 2 * _mm),
            child: pw.Text(
              line.isEmpty ? ' ' : line,
              style: pw.TextStyle(font: fonts.base, fontSize: 11),
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildCapitationCallPdf(
  Member member,
  int year,
  List<Member> members, {
  String lodgeVmName = '',
}) => _buildTreasuryLetterPdf(
  'APPEL DE COTISATION $year',
  capitationCallBody(member, year, members, lodgeVmName: lodgeVmName),
);

Future<Uint8List> buildQuitusPdf(
  Member member,
  int year,
  List<Member> members, {
  String lodgeVmName = '',
}) => _buildTreasuryLetterPdf(
  'QUITUS DE COTISATION $year',
  quitusBody(member, year, members, lodgeVmName: lodgeVmName),
);

// ══════════════════════════════════════════════════════════════════
// PASSEPORT MAÇONNIQUE — document d'identité personnel, sans QR (voir
// member_passport_screen.dart pour le mécanisme de vérification, un jeton
// à durée de vie d'une heure généré à la demande, distinct de ce PDF
// d'archive).
// ══════════════════════════════════════════════════════════════════

/// Nom du V∴M∴, sans dépendre d'une tenue précise (le passeport n'en cite
/// aucune) — même repli que treasury_document_service.dart : réglage de la
/// Loge, sinon le membre portant l'office.
String _passportVmName(List<Member> members, String lodgeVmName) {
  if (lodgeVmName.trim().isNotEmpty) return lodgeVmName.trim();
  final vm = members
      .where((m) => foldLabel(m.function).contains('venerable'))
      .firstOrNull;
  return vm != null ? _memberFullName(vm) : 'Vénérable Maître';
}

Future<Uint8List> buildPassportPdf(
  Member member,
  List<Member> members, {
  String lodgeVmName = '',
}) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();
  final lodge = LodgeConfig.current;
  final vmName = maskPersonName(_passportVmName(members, lodgeVmName));

  pw.Widget row(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 3 * _mm),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 45 * _mm,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: fonts.base, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(18 * _mm),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _lodgeHeader(fonts, logos[0], logos[1]),
          pw.SizedBox(height: 6 * _mm),
          pw.Center(
            child: pw.Text(
              'PASSEPORT MAÇONNIQUE',
              style: pw.TextStyle(font: fonts.bold, fontSize: 16, color: _navy),
            ),
          ),
          pw.SizedBox(height: 8 * _mm),
          pw.Center(
            child: pw.Text(
              '${civiliteTitle(member.civilite)} ${member.fullName}'.trim(),
              style: pw.TextStyle(font: fonts.bold, fontSize: 15),
            ),
          ),
          pw.SizedBox(height: 10 * _mm),
          pw.Container(
            padding: pw.EdgeInsets.all(10 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                row('Grade', member.grade),
                row('Loge', lodge.shortTitle),
                row('Orient', lodge.orientLong),
                row('Obédience', lodge.obedienceAcronym),
                row("Date d'initiation", member.initiationDate),
                row("Date d'entrée", member.entryDate),
              ],
            ),
          ),
          pw.SizedBox(height: 14 * _mm),
          pw.Text(
            'Le présent document atteste que le porteur est régulièrement '
            'affilié à la R∴L∴ ${lodge.name} N°${lodge.number}, à '
            "l'Orient de ${lodge.orient}, sous l'obédience de la Grande "
            'Loge de Bourbon.',
            style: pw.TextStyle(font: fonts.base, fontSize: 10),
          ),
          pw.SizedBox(height: 10 * _mm),
          pw.Text(
            'Par mandatement du V∴M∴ $vmName',
            style: pw.TextStyle(font: fonts.base, fontSize: 10),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// RAPPORT D'ACTIVITÉ POUR LA GRANDE LOGE
// ══════════════════════════════════════════════════════════════════

String _fmtDdMmYyyy(DateTime? d) => d == null
    ? '?'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Document en lecture seule : n'agrège que ce qui est déjà enregistré
/// ailleurs (voir activity_report_service.dart), aucune écriture.
Future<Uint8List> buildActivityReportPdf({
  required DateTime start,
  required DateTime end,
  required List<Member> members,
  required List<Session> sessions,
  required List<ExternalSession> externalSessions,
  required List<Visitor> visitors,
  required List<Dignitary> dignitaries,
  required List<MemberEvent> memberEvents,
}) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();
  final lodge = LodgeConfig.current;
  final doc = pw.Document();

  final effectifs = computeEffectifsSection(
    members,
    memberEvents,
    start: start,
    end: end,
  );
  final activity = computeActivitySection(
    members,
    sessions,
    externalSessions,
    visitors,
    dignitaries,
    start: start,
    end: end,
  );
  final treasury = computeTreasurySection(members, sessions, start: start, end: end);
  final memberStats = computeMemberAttendance(
    members,
    sessions,
    externalSessions,
    start: start,
    end: end,
  ); // déjà triée par taux de présence décroissant
  final planches = computePlancheEntries(sessions, members, start: start, end: end);
  final planchesByAuthor = planchesCountByAuthor(planches);

  pw.Widget sectionTitle(String text) => pw.Padding(
    padding: pw.EdgeInsets.only(top: 8 * _mm, bottom: 4 * _mm),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: fonts.bold, fontSize: 13, color: _navy),
    ),
  );

  pw.Widget emptyNote(String text) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 2 * _mm),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: fonts.base, fontSize: 10, color: PdfColors.grey700),
    ),
  );

  pw.Widget kvRow(String label, String value) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 1.5 * _mm),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 70 * _mm,
          child: pw.Text(label, style: pw.TextStyle(font: fonts.bold, fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(font: fonts.base, fontSize: 10)),
        ),
      ],
    ),
  );

  pw.Widget countTable(Map<String, int> counts) {
    final entries = counts.entries.toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(60), 1: pw.FlexColumnWidth(20)},
      children: [
        for (final e in entries)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(2 * _mm),
                child: pw.Text(e.key, style: pw.TextStyle(font: fonts.base, fontSize: 10)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(2 * _mm),
                child: pw.Text(
                  '${e.value}',
                  style: pw.TextStyle(font: fonts.base, fontSize: 10),
                ),
              ),
            ],
          ),
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(18 * _mm, 14 * _mm, 18 * _mm, 18 * _mm),
      theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
      build: (context) => [
        _lodgeHeader(fonts, logos[0], logos[1]),
        pw.SizedBox(height: 6 * _mm),
        pw.Center(
          child: pw.Text(
            'RAPPORT D\'ACTIVITÉ — R∴L∴ ${lodge.name}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: fonts.bold, fontSize: 15, color: _navy),
          ),
        ),
        pw.SizedBox(height: 2 * _mm),
        pw.Center(
          child: pw.Text(
            'Période du ${_fmtDdMmYyyy(start)} au ${_fmtDdMmYyyy(end)} '
            '— édité le ${_fmtDdMmYyyy(DateTime.now())}',
            style: pw.TextStyle(font: fonts.base, fontSize: 10, color: PdfColors.grey700),
          ),
        ),

        // ─── 1. Effectifs ───────────────────────────────────────
        sectionTitle('1. Effectifs de la Loge'),
        pw.Text(
          'Répartition actuelle par grade',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
        ),
        pw.SizedBox(height: 2 * _mm),
        countTable(effectifs.byGrade),
        pw.SizedBox(height: 4 * _mm),
        pw.Text(
          'Répartition actuelle par statut',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
        ),
        pw.SizedBox(height: 2 * _mm),
        countTable(effectifs.byStatus),
        pw.SizedBox(height: 4 * _mm),
        kvRow('Nouveaux membres entrés', '${effectifs.newMembers.length}'),
        for (final m in effectifs.newMembers)
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 4 * _mm, bottom: 1 * _mm),
            child: pw.Text(
              '• ${m.fullName} — entré le ${m.entryDate}',
              style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
            ),
          ),
        kvRow('Élévations de grade', '${effectifs.elevations.length}'),
        for (final e in effectifs.elevations)
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 4 * _mm, bottom: 1 * _mm),
            child: pw.Text(
              '• ${e.fromValue} → ${e.toValue} (${e.date})',
              style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
            ),
          ),
        kvRow('Changements de statut', '${effectifs.statusChanges.length}'),
        for (final e in effectifs.statusChanges)
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 4 * _mm, bottom: 1 * _mm),
            child: pw.Text(
              '• ${e.fromValue} → ${e.toValue} (${e.date})',
              style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
            ),
          ),
        if (effectifs.newMembers.isEmpty &&
            effectifs.elevations.isEmpty &&
            effectifs.statusChanges.isEmpty)
          emptyNote('Aucun mouvement (entrée, élévation, changement de statut) enregistré sur la période.'),

        // ─── 2. Activité et assiduité ───────────────────────────
        sectionTitle('2. Activité et assiduité'),
        if (activity.sessionsByDegree.isEmpty)
          emptyNote('Aucune tenue tenue sur la période.')
        else ...[
          pw.Text(
            'Tenues tenues sur la période, par degré',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
          ),
          pw.SizedBox(height: 2 * _mm),
          countTable(activity.sessionsByDegree),
          pw.SizedBox(height: 4 * _mm),
          kvRow(
            'Taux de présence moyen',
            '${(activity.averagePresenceRate * 100).toStringAsFixed(1)} %',
          ),
        ],
        pw.SizedBox(height: 2 * _mm),
        pw.Text('Rayonnement extérieur', style: pw.TextStyle(font: fonts.bold, fontSize: 10.5)),
        pw.SizedBox(height: 2 * _mm),
        kvRow('Visites de membres dans d\'autres Loges', '${activity.externalVisitCount}'),
        kvRow('Visiteurs distincts reçus', '${activity.distinctVisitorCount}'),
        kvRow('Dignitaires distincts reçus', '${activity.distinctDignitaryCount}'),
        if (activity.externalVisitCount == 0 &&
            activity.distinctVisitorCount == 0 &&
            activity.distinctDignitaryCount == 0)
          emptyNote('Aucune tenue extérieure, aucun Visiteur ni Dignitaire enregistré sur la période.')
        else if (activity.hasMultipleObediences) ...[
          pw.SizedBox(height: 2 * _mm),
          pw.Text(
            'Détail par obédience (Visiteurs + Dignitaires)',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
          ),
          pw.SizedBox(height: 2 * _mm),
          countTable(activity.byObedience),
        ],
        if (activity.externalVisitEntries.isNotEmpty) ...[
          pw.SizedBox(height: 4 * _mm),
          pw.Text(
            'Visites faites par nos membres ailleurs',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
          ),
          pw.SizedBox(height: 2 * _mm),
          for (final e in activity.externalVisitEntries)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 1.5 * _mm),
              child: pw.Text(
                '${_fmtDdMmYyyy(e.date)} — ${e.organizingLodge.isEmpty ? 'Loge non renseignée' : e.organizingLodge} — '
                '${e.memberNames.isEmpty ? 'aucun membre retrouvé' : e.memberNames.join(', ')}',
                style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
              ),
            ),
        ],
        if (activity.receivedGuestsEntries.isNotEmpty) ...[
          pw.SizedBox(height: 4 * _mm),
          pw.Text(
            'Visiteurs et Dignitaires reçus',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
          ),
          pw.SizedBox(height: 2 * _mm),
          for (final e in activity.receivedGuestsEntries)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 1.5 * _mm),
              child: pw.Text(
                '${_fmtDdMmYyyy(e.date)} — '
                'Visiteurs : ${e.visitorNames.isEmpty ? 'aucun' : e.visitorNames.join(', ')} — '
                'Dignitaires : ${e.dignitaryNames.isEmpty ? 'aucun' : e.dignitaryNames.join(', ')}',
                style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
              ),
            ),
        ],

        // ─── 3. Statistiques des membres ─────────────────────────
        sectionTitle('3. Statistiques des membres'),
        if (memberStats.isEmpty)
          emptyNote('Aucun membre enregistré.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(28),
              1: pw.FlexColumnWidth(16),
              2: pw.FlexColumnWidth(11),
              3: pw.FlexColumnWidth(11),
              4: pw.FlexColumnWidth(11),
              5: pw.FlexColumnWidth(11),
              6: pw.FlexColumnWidth(11),
              7: pw.FlexColumnWidth(11),
              8: pw.FlexColumnWidth(9),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _grey),
                children: [
                  for (final h in const [
                    'Membre',
                    'Grade',
                    'Élig.',
                    'Présent',
                    'Excusé',
                    'Absence',
                    'Taux',
                    'Tenues ext.',
                    'Planches',
                  ])
                    pw.Padding(
                      padding: pw.EdgeInsets.all(1.5 * _mm),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(font: fonts.bold, fontSize: 8.5),
                      ),
                    ),
                ],
              ),
              for (final s in memberStats)
                pw.TableRow(
                  children: [
                    for (final v in [
                      s.fullName,
                      s.grade,
                      '${s.eligibleCount}',
                      '${s.presentCount}',
                      '${s.excusedCount}',
                      '${s.unexcusedAbsences}',
                      '${(s.attendanceRate * 100).toStringAsFixed(0)} %',
                      '${s.externalVisits}',
                      '${s.planchesCount}',
                    ])
                      pw.Padding(
                        padding: pw.EdgeInsets.all(1.5 * _mm),
                        child: pw.Text(
                          v,
                          style: pw.TextStyle(font: fonts.base, fontSize: 8.5),
                        ),
                      ),
                  ],
                ),
            ],
          ),

        // ─── 4. Trésorerie ───────────────────────────────────────
        sectionTitle('4. Trésorerie'),
        kvRow('Cotisation Loge due', _euroLabel(treasury.lodgeDuesTotal)),
        kvRow('Cotisation Loge versée', _euroLabel(treasury.lodgeDuesPaidTotal)),
        kvRow('Cotisation Ordre due', _euroLabel(treasury.orderDuesTotal)),
        kvRow('Cotisation Ordre versée', _euroLabel(treasury.orderDuesPaidTotal)),
        kvRow('Tronc de la Veuve récolté', _euroLabel(treasury.troncTotal)),

        // ─── 5. Planches tracées étudiées ───────────────────────
        sectionTitle('5. Planches tracées étudiées'),
        if (planches.isEmpty)
          emptyNote('Aucune planche identifiée sur la période.')
        else ...[
          kvRow('Total de planches présentées', '${planches.length}'),
          pw.SizedBox(height: 2 * _mm),
          for (final p in planches)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 2 * _mm),
              child: pw.Text(
                '${p.sessionLabel} (${p.degree}) — '
                '${p.title.isEmpty ? '(sans titre)' : '« ${p.title} »'} — '
                '${p.authorName.isEmpty ? 'auteur non retrouvé' : p.authorName}',
                style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
              ),
            ),
          if (planchesByAuthor.length > 1) ...[
            pw.SizedBox(height: 2 * _mm),
            pw.Text(
              'Sous-total par auteur',
              style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
            ),
            pw.SizedBox(height: 2 * _mm),
            countTable(planchesByAuthor),
          ],
        ],
      ],
    ),
  );
  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// DEMANDE (Suggestions / Dysfonctionnements — Parvis)
// ══════════════════════════════════════════════════════════════════

/// Ticket PDF d'une Demande (Suggestions / Dysfonctionnements), déposée par
/// le V∴M∴ ou le Secrétaire depuis le Parvis — voir support_request_screen.dart.
/// Archivé sur Drive et joint au mail envoyé à gaudin.bruno974@gmail.com :
/// seul ce PDF porte le texte de la demande, jamais stocké en base.
Future<Uint8List> buildSupportRequestPdf({
  required int chrono,
  required String objet,
  required Member requester,
  required String message,
}) async {
  final fonts = await _loadLodgeFonts();
  final logos = await _loadLogos();

  pw.Widget row(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 3 * _mm),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 32 * _mm,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: fonts.base, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(18 * _mm),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _lodgeHeader(fonts, logos[0], logos[1]),
          pw.SizedBox(height: 8 * _mm),
          pw.Center(
            child: pw.Text(
              'DEMANDE N° $chrono',
              style: pw.TextStyle(font: fonts.bold, fontSize: 16, color: _navy),
            ),
          ),
          pw.SizedBox(height: 10 * _mm),
          pw.Container(
            padding: pw.EdgeInsets.all(10 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                row('Date', DateFormat('dd/MM/yyyy').format(DateTime.now())),
                row('Objet', objet),
                row(
                  'Demandeur',
                  '${civiliteAbbrev(requester.civilite)} ${requester.fullName}'
                      .trim(),
                ),
                row('Email', requester.email),
                row('Téléphone', requester.phone),
              ],
            ),
          ),
          pw.SizedBox(height: 10 * _mm),
          pw.Text(
            message,
            style: pw.TextStyle(font: fonts.base, fontSize: 11),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

String _euroLabel(num v) => '${v.toStringAsFixed(2)} €';
