// Génération PDF pour les corps de Hauts Grades (IAH-MES, MAA-Kherou) —
// fichier séparé de pdf_service.dart (dédié aux 4 loges bleues). Gabarit
// visuel commun (logo, en-tête, signataire « Trois Fois Puissant Maître »),
// habillé différemment par corps (voir _logoAsset/hgInstitutionHeader/
// hgDegreeOrdinalPhrase/hgDegreeNamePhrase ci-dessous, ces trois derniers
// publics pour être réutilisés par hg_invitation_service.dart) : IAH-MES
// suit le ladder 4°-14° du Collège de Perfection, MAA-Kherou travaille
// uniquement au grade de Maître, sans ladder ni numéro de degré — confirmé
// par l'utilisateur. Le contenu de l'ordre du jour est, comme pour les
// loges bleues, entièrement piloté par la tenue elle-même (Session —
// demande explicite de l'utilisateur, « copie l'intégralité »). Recopie
// volontairement quelques utilitaires de pdf_service.dart (polices, pied de
// page) plutôt que de les exposer publiquement depuis ce fichier partagé
// par les 4 loges bleues.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show imageFromAssetBundle;

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/hg_session.dart' show kIahMesDegreeNames;
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../utils/name_mask.dart';
import '../models/civilite.dart' show civiliteArticleAbbrev;
import 'agape_payment_service.dart';
import 'pdf_service.dart'
    show
        getMasonicDate,
        getSothiacDate,
        formatDateFR,
        officePlacement,
        directPlacement,
        plancheOrdreDuJour,
        plancheTroncSentence;

const double _mm = PdfPageFormat.mm;
const _navy = PdfColor.fromInt(0xFF0C235C);
const _violet = PdfColor.fromInt(0xFF701A75);
const _grey = PdfColor.fromInt(0xFFD9D9D9);

class _PdfFonts {
  final pw.Font base;
  final pw.Font bold;
  _PdfFonts(this.base, this.bold);
}

Future<_PdfFonts> _loadFonts() async {
  final base = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  return _PdfFonts(base, bold);
}

// Feuille de présence : police à empattement (Times), comme les loges
// bleues (voir buildEmargementPdf, pdf_service.dart).
_PdfFonts _serifFonts() => _PdfFonts(pw.Font.times(), pw.Font.timesBold());

Future<pw.ImageProvider?> _loadImage(String path) async {
  try {
    return await imageFromAssetBundle(path);
  } catch (_) {
    return null;
  }
}

pw.Widget _footer(pw.Context context) => pw.Container(
  margin: pw.EdgeInsets.only(top: 4 * _mm),
  child: pw.Row(
    children: [
      pw.Expanded(
        child: pw.Text(
          '© Grande Loge de Bourbon (GLDB) - N° RNA W9R2011523',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
      ),
      pw.Text(
        '${context.pageNumber}/${context.pagesCount}',
        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
      ),
    ],
  ),
);

String _formatDateLong(String? dateStr) {
  final d = DateTime.tryParse(dateStr ?? '');
  if (d == null) return 'date à préciser';
  final formatted = DateFormat('EEEE d MMMM y', 'fr_FR').format(d);
  return formatted[0].toUpperCase() + formatted.substring(1);
}

int _sessionDegree(Session session) {
  final raw = session.degreTravail ?? session.degree;
  return int.tryParse(raw) ?? 4;
}

/// Habillage propre à chaque corps : logo, libellé institutionnel et
/// libellé de degré — IAH-MES suit le ladder 4°-14° du Collège de
/// Perfection, MAA-Kherou travaille uniquement au grade de Maître, sans
/// ladder ni numéro de degré (confirmé par l'utilisateur).
String _logoAsset(HgBody body) => body.key == kMaaKherou.key
    ? 'assets/pdf/MAA-Kherou.jpg'
    : 'assets/pdf/Iah-Mes.jpg';

String hgInstitutionHeader(HgBody body) => body.key == kMaaKherou.key
    ? 'Atelier ${body.label}'
    : 'Collège de Perfection ${body.label}';

String hgInstitutionHeaderBlock(HgBody body) => body.key == kMaaKherou.key
    ? 'ATELIER ${body.label.toUpperCase()}\n'
          'Vallée de Saint-Pierre — Temple Thérèse Eliseman'
    : 'COLLÈGE DE PERFECTION ${body.label.toUpperCase()} N°1\n'
          'Vallée de Saint-Pierre — Temple Thérèse Eliseman';

String _correspondenceEmail(HgBody body) => body.key == kMaaKherou.key
    ? 'maakherou.sstr@gmail.com'
    : 'iahmes.sstr@gmail.com';

String hgDegreeOrdinalPhrase(HgBody body, int degree) =>
    body.key == kMaaKherou.key ? 'grade de Maître' : '${degree}e degré';

String hgDegreeNamePhrase(HgBody body, int degree) =>
    body.key == kMaaKherou.key ? 'Maître' : (kIahMesDegreeNames[degree] ?? '');

String _degreeObjectPhrase(HgBody body, int degree, String degreeName) =>
    body.key == kMaaKherou.key
    ? 'au grade de Maître'
    : 'au ${degree}e degré — $degreeName';

String _membersSectionLabel(HgBody body) =>
    body.key == kMaaKherou.key ? 'MEMBRES DE L\'ATELIER' : 'MEMBRES DU COLLÈGE';

String _sessionHeure(Session session) {
  final dt = session.dateTime;
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) return '19h30';
  return '${dt.hour.toString().padLeft(2, '0')}h'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// Convocation d'une tenue du Collège de Perfection IAH-MES — gabarit visuel
/// fixe (voir hg_session.dart pour la nomenclature des degrés), contenu de
/// l'ordre du jour piloté par la tenue (travaux fixes + ordres du jour
/// complémentaires, à la manière des loges bleues).
Future<Uint8List> buildIahMesConvocationPdf(
  HgBody body,
  Session session,
) async {
  final fonts = await _loadFonts();
  final logoIahMes = await _loadImage(_logoAsset(body));
  // Logo de droite : aigle bicéphale du Souverain Sanctuaire pour IAH-MES
  // (demande de l'utilisateur), logo Souverain Sanctuaire d'origine pour
  // MAA-Kherou, inchangé.
  final logoSouverainSanctuaire = await _loadImage(
    body.key == kIahMes.key
        ? 'assets/pdf/Logo-SSTR-IAH-MES.jpg'
        : 'assets/pdf/Souverain-Sanctuaire.jpg',
  );
  final degree = _sessionDegree(session);
  final lieu = (session.lieuReunionExtra ?? '').trim().isEmpty
      ? 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre'
      : session.lieuReunionExtra!.trim();
  final signerName = (session.vmName ?? '').trim().isEmpty
      ? 'Trois Fois Puissant Maître'
      : session.vmName!.trim();
  final masonicDate = getMasonicDate(session.dateTime);
  final sothiacDate = getSothiacDate(session.dateTime);

  final lecturePlanche = session.extra['lecturePlancheText'] as String?;
  final fixedWorks = [
    session.travail1,
    session.travail2,
    session.travail3,
    lecturePlanche,
  ].whereType<String>().where((t) => t.trim().isNotEmpty).toList();
  final complementary = session.agendaItems
      .where((a) => a.text.trim().isNotEmpty)
      .map((a) => a.text.trim())
      .toList();
  final cloture = (session.ligneCloture ?? '').trim();

  final doc = pw.Document(
    author: 'Grande Loge de Bourbon (GLDB) — N° RNA W9R2011523',
  );

  pw.Widget logoBox(pw.ImageProvider? img) => pw.SizedBox(
    width: 24 * _mm,
    height: 24 * _mm,
    child: img == null ? pw.SizedBox() : pw.Image(img, fit: pw.BoxFit.contain),
  );

  // Ligne numérotée de l'ordre du jour — le libellé « Thème de la Tenue : »
  // (inséré automatiquement par _travailCollectifText) est mis en gras,
  // le reste du texte du point reste en style normal.
  pw.Widget numberedLine(int n, String text) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 5 * _mm),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 7 * _mm,
          child: pw.Text(
            '$n.',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10, color: _navy),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in text.split('\n'))
                // Une ligne vide (saut de paragraphe dans le texte source)
                // n'a aucune hauteur propre une fois isolée dans son propre
                // pw.Text — un SizedBox explicite recrée l'espacement.
                if (line.isEmpty)
                  pw.SizedBox(height: 10 * 1.5)
                else
                  pw.Text(
                    line,
                    style: pw.TextStyle(
                      font: line.trim() == 'Thème de la Tenue :'
                          ? fonts.bold
                          : fonts.base,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
            ],
          ),
        ),
      ],
    ),
  );

  // La ligne de clôture porte déjà son numéro dans le texte (voir
  // _ligneCloture) — on l'extrait pour la faire passer par numberedLine et
  // garder la même mise en forme que les autres points de l'ordre du jour.
  final clotureMatch = RegExp(
    r'^(\d+)\.\s*(.*)$',
    dotAll: true,
  ).firstMatch(cloture);
  final pw.Widget clotureLine = clotureMatch == null
      ? pw.Text(
          cloture,
          style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
        )
      : numberedLine(int.parse(clotureMatch.group(1)!), clotureMatch.group(2)!);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(16 * _mm),
      footer: _footer,
      build: (context) => [
        pw.Text(
          '« la vie de l\'esprit est une aventure merveilleuse mais aussi '
          'déconcertante, il s\'agit d\'avancer sans but ni projet, aucun '
          'itinéraire tracé à l\'avance » Maître Eckhart',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: fonts.base,
            fontStyle: pw.FontStyle.italic,
            fontSize: 9.5,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 7 * _mm),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            logoBox(logoIahMes),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Souverain Sanctuaire',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fonts.bold,
                      fontSize: 17,
                      color: _navy,
                    ),
                  ),
                  pw.Text(
                    'Traditionnel de la Réunion',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fonts.base,
                      fontSize: 13,
                      color: _navy,
                    ),
                  ),
                  pw.SizedBox(height: 2 * _mm),
                  pw.Text(
                    'GRANDE LOGE DE BOURBON',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                  ),
                  pw.Text(
                    'FRANCS-MAÇONS TRAVAILLANT AU RITE ANCIEN ET PRIMITIF DE '
                    'MEMPHIS-MISRAÏM',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fonts.base, fontSize: 6.5),
                  ),
                ],
              ),
            ),
            pw.Column(
              children: [
                pw.Text(
                  'A∴L∴G∴D∴S∴A∴D∴M∴',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                ),
                pw.SizedBox(height: 2 * _mm),
                logoBox(logoSouverainSanctuaire),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 7 * _mm),
        pw.Text(
          hgInstitutionHeaderBlock(body),
          style: pw.TextStyle(font: fonts.bold, fontSize: 9),
        ),
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          'Correspondance : Trois Fois Puissant Maître $signerName\n'
          '${_correspondenceEmail(body)}',
          style: pw.TextStyle(
            font: fonts.base,
            fontSize: 8.5,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 7 * _mm),
        pw.Text(
          'CONVOCATION',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 13, color: _navy),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Text(
          'Mes Très Chers FF∴ et Bien-Aimées SS∴,',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
        ),
        pw.SizedBox(height: 2 * _mm),
        pw.Text(
          'J\'ai le plaisir de vous faire savoir que vous êtes fraternellement '
          'convoqués à la prochaine rencontre de notre '
          '${hgInstitutionHeader(body)}, au ${hgDegreeOrdinalPhrase(body, degree)}, '
          'qui se tiendra :',
          style: pw.TextStyle(font: fonts.base, fontSize: 10.5, height: 1.4),
        ),
        pw.SizedBox(height: 4 * _mm),
        pw.Text(
          'Le ${_formatDateLong(session.date)} à ${_sessionHeure(session)}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5, color: _navy),
        ),
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          masonicDate,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5, color: _navy),
        ),
        pw.SizedBox(height: 1 * _mm),
        pw.Text(
          sothiacDate,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5, color: _navy),
        ),
        pw.SizedBox(height: 5 * _mm),
        pw.Text(
          'Au $lieu',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Text(
          'ORDRE DU JOUR',
          style: pw.TextStyle(font: fonts.bold, fontSize: 12, color: _navy),
        ),
        pw.Divider(color: PdfColors.grey400),
        for (int i = 0; i < fixedWorks.length; i++)
          numberedLine(i + 1, fixedWorks[i]),
        for (int i = 0; i < complementary.length; i++)
          numberedLine(fixedWorks.length + i + 1, complementary[i]),
        if (cloture.isNotEmpty) clotureLine,
        if (session.suitAgapes) ...[
          pw.SizedBox(height: 8 * _mm),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 2 * _mm),
          pw.Text(
            'AGAPES FRATERNELLES',
            style: pw.TextStyle(font: fonts.bold, fontSize: 11, color: _navy),
          ),
          pw.SizedBox(height: 3 * _mm),
          pw.Text(
            'À l\'issue de nos travaux, des agapes fraternelles nous '
            'réuniront dans la convivialité et le partage.',
            style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
          ),
          if ((session.montantMedaille ?? 0) > 0) ...[
            pw.SizedBox(height: 1.5 * _mm),
            pw.Text(
              'Participation aux agapes : ${session.montantMedaille} €',
              style: pw.TextStyle(font: fonts.bold, fontSize: 10),
            ),
          ],
        ],
        pw.SizedBox(height: 14 * _mm),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Trois Fois Puissant Maître',
                style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
              ),
              pw.Text(
                signerName,
                style: pw.TextStyle(font: fonts.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// FEUILLE DE PRÉSENCE / ÉMARGEMENT — même principe que buildEmargementPdf
// (pdf_service.dart, loges bleues), gabarit visuel propre à IAH-MES.
// ══════════════════════════════════════════════════════════════════

class _HgRow {
  final String lastName;
  final String firstName;
  final String role;
  final String lodge;
  final String? signature;
  const _HgRow(
    this.lastName,
    this.firstName,
    this.role,
    this.lodge,
    this.signature,
  );
}

Uint8List? _decodeHgSignature(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final idx = dataUrl.indexOf('base64,');
  final b64 = idx >= 0 ? dataUrl.substring(idx + 7) : dataUrl;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

pw.Widget _hgCell(
  _PdfFonts fonts,
  String? value,
  double minHeight, {
  int maxLines = 2,
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

pw.Widget _hgSignatureCell(Uint8List? bytes, double minHeight) => pw.Container(
  constraints: pw.BoxConstraints(minHeight: minHeight),
  alignment: pw.Alignment.center,
  padding: pw.EdgeInsets.all(1 * _mm),
  child: bytes == null
      ? pw.SizedBox()
      : pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
);

/// Feuille de présence / émargement d'une tenue de Hauts Grades — même
/// principe que les loges bleues (tableau Nom/Prénom/Fonction/Loge/
/// Signature, une section par catégorie), gabarit visuel IAH-MES.
Future<Uint8List> buildIahMesEmargementPdf(
  HgBody body,
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) async {
  final fonts = _serifFonts();
  final fallback = await _loadFonts();
  final logo = await _loadImage(_logoAsset(body));
  final doc = pw.Document(
    author: 'Grande Loge de Bourbon (GLDB) — N° RNA W9R2011523',
  );

  final signatures = session.signatures;
  final degree = _sessionDegree(session);
  final degreeName = hgDegreeNamePhrase(body, degree);
  final sessionNumber =
      session.chrono?.toInt().toString() ?? session.sessionNumber ?? '';
  final location = (session.lieuReunionExtra ?? '').trim().isEmpty
      ? 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre'
      : session.lieuReunionExtra!.trim();

  final memberRows = members
      .where((m) => session.presentIds.contains(m.id))
      .map(
        (m) => _HgRow(
          maskPersonName(m.lastName),
          maskPersonName(m.firstName),
          m.function.isNotEmpty && m.function != 'Aucun'
              ? m.function
              : 'Membre',
          body.label,
          signatures[m.id],
        ),
      )
      .toList();
  final visitorRows = visitors
      .where((v) => session.visitorIds.contains(v.id))
      .map(
        (v) => _HgRow(
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
        (d) => _HgRow(
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
            height: 28 * _mm,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        ),
      pw.SizedBox(height: 4 * _mm),
      pw.Text(
        hgInstitutionHeader(body),
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

  pw.Table dataTable(List<_HgRow?> rows, double rowHeight) {
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
              _hgCell(fonts, row?.lastName, rowHeight),
              _hgCell(fonts, row?.firstName, rowHeight),
              _hgCell(fonts, row?.role, rowHeight),
              _hgCell(fonts, row?.lodge, rowHeight),
              _hgSignatureCell(_decodeHgSignature(row?.signature), rowHeight),
            ],
          ),
      ],
    );
  }

  final memberSlots = List<_HgRow?>.generate(
    20,
    (i) => i < memberRows.length ? memberRows[i] : null,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(20 * _mm, 12 * _mm, 20 * _mm, 18 * _mm),
      theme: pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.bold,
        fontFallback: [fallback.base, fallback.bold],
      ),
      footer: _footer,
      build: (context) => [
        header(),
        metaLine(
          'Objet : ',
          'Tenue ${_degreeObjectPhrase(body, degree, degreeName)}',
        ),
        metaLine('Fiche N° : ', sessionNumber),
        metaLine('Date : ', _formatDateLong(session.date)),
        metaLine('Lieu : ', location),
        pw.SizedBox(height: 8 * _mm),
        sectionTable(_membersSectionLabel(body)),
        dataTable(memberSlots, 8 * _mm),
        if (visitorRows.isNotEmpty) ...[
          pw.NewPage(),
          sectionTable('INVITÉS'),
          dataTable(visitorRows, 8 * _mm),
        ],
        if (dignitaryRows.isNotEmpty) ...[
          pw.NewPage(),
          sectionTable('DIGNITAIRES'),
          dataTable(dignitaryRows, 8 * _mm),
        ],
      ],
    ),
  );

  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// PLANCHE TRACÉE — texte libre (session.plancheDraftText) + signature
// unique du Trois Fois Puissant Maître, gabarit visuel IAH-MES.
// ══════════════════════════════════════════════════════════════════

/// Construit le texte intégral de la planche tracée d'une tenue de Hauts
/// Grades — même principe et même structure rituelle que
/// buildPlancheTraceeText (pdf_service.dart, loges bleues), demande
/// explicite de l'utilisateur ; adapté uniquement sur les termes propres à
/// IAH-MES/MAA-Kherou (institution, « Trois Fois Puissant Maître » au lieu
/// de « Vénérable Maître », degré aux Hauts Grades au lieu du degré
/// symbolique). Fonction pure : sert à pré-remplir l'éditeur de planche et
/// à générer le corps du PDF si `session.plancheDraftText` est vide.
String buildIahMesPlancheTraceeText(
  HgBody body,
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
  int chrono, {
  num? troncAmount,
  String? sacPropositions,
  List<String>? travauxNotes,
}) {
  final paras = <String>[];
  // session.vmName est déjà saisi sous forme abrégée par l'officier (ex.
  // « Jean-Pierre T∴ »), sans nom de famille en clair — même convention que
  // le reste de la convocation IAH-MES (hg_pdf_service.dart), pas de
  // maskPersonName ici (à la différence des loges bleues, où le nom du
  // V∴M∴ vient en clair d'une fiche Membre).
  final signerName = (session.vmName ?? '').trim().isEmpty
      ? 'Trois Fois Puissant Maître'
      : session.vmName!.trim();
  final dateFR = formatDateFR(session.dateReprise ?? session.date);
  final degree = int.tryParse(session.degreTravail ?? session.degree) ?? 4;
  final degreePhrase = hgDegreeOrdinalPhrase(body, degree);
  final lieu = (session.lieuReunionExtra ?? '').trim().isEmpty
      ? 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre'
      : session.lieuReunionExtra!.trim();
  final institution = hgInstitutionHeader(body);

  paras.add('Planche Tracée de la Tenue Régulière N°$chrono du $dateFR');
  paras.add('De $institution, au $lieu');
  paras.add(
    'Trois Fois Puissant Maître en chaire et vous tous mes Frères et Sœurs '
    'en vos grades et qualités.',
  );
  paras.add(
    'Protocole de la Tenue '
    '${session.type == 'Solennelle' ? 'Solennelle' : (session.typeTenue ?? (session.type.isNotEmpty ? session.type : 'Régulière'))} '
    'du $dateFR de Ère Vulgaire.',
  );
  paras.add(
    'Les Sœurs et Frères composant $institution, régulièrement convoqués, '
    'sont traditionnellement réunis en un lieu très pur, très saint et très '
    'éclairé par la lumière d’Egypte, lieu où règne la Paix, la Joie et '
    'l’Harmonie.',
  );
  paras.add(
    'Les Sœurs et Frères sont éclairés à l’orient par la sagesse du Trois '
    'Fois Puissant Maître en chaire $signerName.',
  );
  paras.add(
    'Les Sœurs et Frères dont le nom figure sur le registre des présences, '
    'nous ont fait la joie d’assister à nos travaux.',
  );

  // Membres excusés.
  final excused = session.excusedIds
      .map((id) => members.where((m) => m.id == id).firstOrNull)
      .whereType<Member>()
      .toList();
  if (excused.isNotEmpty) {
    final noms = excused
        .asMap()
        .entries
        .map(
          (e) =>
              '${civiliteArticleAbbrev(e.value.civilite, capitalize: e.key == 0)} '
              '${maskPersonName('${e.value.firstName} ${e.value.lastName}'.trim())}',
        )
        .join(', ');
    paras.add(
      '$noms membre(s) de $institution sont absents excusés. (Voir la '
      'liste des membres excusés)',
    );
  } else {
    paras.add('Aucun membre de $institution n’est absent excusé.');
  }

  // Invités.
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
    return null;
  }

  String? roleOfDignitary(Dignitary d) {
    final r = (session.dignitaryRoles[d.id] ?? '').trim();
    return r.isEmpty ? null : r;
  }

  bool isOffice(String role) => officePlacement.containsKey(role);
  String? placementOf(Visitor v) {
    final role = roleOf(v);
    if (role == null) return null;
    return officePlacement[role] ?? directPlacement[role];
  }

  String? placementOfDignitary(Dignitary d) {
    final role = roleOfDignitary(d);
    if (role == null) return null;
    return officePlacement[role] ?? directPlacement[role];
  }

  String placementSentence(Visitor v, String placement, String role) {
    final who =
        '${civiliteArticleAbbrev(v.civilite)} '
        '${maskPersonName('${v.firstName} ${v.lastName}'.trim())} (${v.lodge})';
    final qualite = isOffice(role) ? ' en qualité de $role' : '';
    switch (placement) {
      case 'Colonne du Midi':
        return 'Au Midi, a pris place $who$qualite.';
      case 'Colonne du Nord':
        return 'Au Nord, a pris place $who$qualite.';
      case 'Occident':
        return 'À l’Occident, à la porte d’entrée à l’intérieur, a pris '
            'place $who$qualite.';
      default:
        return 'À l’Orient, a pris place $who$qualite.';
    }
  }

  String placementSentenceDignitary(
    Dignitary d,
    String placement,
    String role,
  ) {
    final lodgePart = d.lodge.isNotEmpty ? ' (${d.lodge})' : '';
    final who =
        '${civiliteArticleAbbrev(d.civilite)} '
        '${maskPersonName(d.fullName)}$lodgePart';
    final qualite = isOffice(role) ? ' en qualité de $role' : '';
    switch (placement) {
      case 'Colonne du Midi':
        return 'Au Midi, a pris place $who$qualite.';
      case 'Colonne du Nord':
        return 'Au Nord, a pris place $who$qualite.';
      case 'Occident':
        return 'À l’Occident, à la porte d’entrée à l’intérieur, a pris '
            'place $who$qualite.';
      default:
        return 'À l’Orient, a pris place $who$qualite.';
    }
  }

  final visitorOrientEntries = presentVisitors
      .where(
        (v) =>
            placementOf(v) == 'Orient' &&
            roleOf(v) != 'Orateur' &&
            isOffice(roleOf(v) ?? ''),
      )
      .map(
        (v) =>
            '${maskPersonName('${v.firstName} ${v.lastName}'.trim())} '
            '(${roleOf(v)} – ${v.lodge})',
      );
  final dignitaryOrientEntries = presentDignitaries
      .where(
        (d) =>
            placementOfDignitary(d) == 'Orient' &&
            roleOfDignitary(d) != 'Orateur',
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
      'A l’Orient, sont venus soutenir nos travaux les dignitaires '
      'suivants : ${orientEntries.join(', ')}.',
    );
  }

  final orateurVisitor = presentVisitors
      .where((v) => roleOf(v) == 'Orateur')
      .firstOrNull;
  final orateurDignitary = presentDignitaries
      .where((d) => roleOfDignitary(d) == 'Orateur')
      .firstOrNull;
  final orateurName = (session.plancheOrateurName ?? '').trim().isNotEmpty
      ? maskPersonName(session.plancheOrateurName!.trim())
      : orateurVisitor != null
      ? maskPersonName(
          '${orateurVisitor.firstName} ${orateurVisitor.lastName}'.trim(),
        )
      : orateurDignitary != null
      ? maskPersonName(orateurDignitary.fullName)
      : null;
  final orateurCivilite = (session.plancheOrateurName ?? '').trim().isNotEmpty
      ? ''
      : orateurVisitor?.civilite ?? orateurDignitary?.civilite ?? '';
  paras.add(
    orateurName != null
        ? 'Le poste d’Orateur est occupé par '
              '${civiliteArticleAbbrev(orateurCivilite)} $orateurName.'
        : 'Le poste d’Orateur est resté vide.',
  );

  for (final v in presentVisitors) {
    final role = roleOf(v);
    final placement = placementOf(v);
    if (role == 'Orateur') continue;
    if (placement == null) continue;
    if (placement == 'Orient' && isOffice(role ?? '')) continue;
    paras.add(placementSentence(v, placement, role as String));
  }

  for (final d in presentDignitaries) {
    final role = roleOfDignitary(d);
    if (role == null || role == 'Orateur') continue;
    final placement = placementOfDignitary(d);
    if (placement == null || placement == 'Orient') continue;
    paras.add(placementSentenceDignitary(d, placement, role));
  }

  paras.add('La planche tracée de nos derniers travaux a été adoptée.');

  paras.add('L’ordre du jour de la Tenue a appelé :');
  final items = plancheOrdreDuJour(session);
  final notes = travauxNotes ?? session.plancheTravauxNotes;
  for (var idx = 0; idx < items.length; idx++) {
    paras.add('${idx + 1}. ${items[idx]}');
    final note = (idx < notes.length ? notes[idx] : '').trim();
    if (note.isNotEmpty) paras.add(note);
  }

  paras.add(
    plancheTroncSentence(
      troncAmount ?? session.troncAmount,
      sacPropositions ?? session.sacPropositions ?? '',
      officerTitle: 'Trois Fois Puissant Maître',
    ),
  );

  paras.add(
    'Les Travaux sont ensuite fermés au $degreePhrase. Au cours de ce '
    'Cérémonial, les Sœurs et les Frères forment une Chaîne d’Union '
    'Fraternelle, selon le Rite, puis se séparent en jurant de garder le '
    'Silence sur les Travaux de ce Jour.',
  );
  paras.add('J’ai dit Trois Fois Puissant Maître,');

  return paras.join('\n\n');
}

Future<Uint8List> buildIahMesPlancheTraceePdf(
  HgBody body,
  Session session,
  int chrono, {
  List<Member> members = const [],
  List<Visitor> visitors = const [],
  List<Dignitary> dignitaries = const [],
}) async {
  final fonts = await _loadFonts();
  final logo = await _loadImage(_logoAsset(body));
  final doc = pw.Document(
    author: 'Grande Loge de Bourbon (GLDB) — N° RNA W9R2011523',
  );

  final signerName = (session.vmName ?? '').trim().isEmpty
      ? 'Trois Fois Puissant Maître'
      : session.vmName!.trim();
  // Le texte édité et enregistré prime sur le texte généré automatiquement
  // (même principe que plancheBodyText, pdf_service.dart, loges bleues).
  final draft = (session.plancheDraftText ?? '').trim();
  final text = draft.isNotEmpty
      ? draft
      : buildIahMesPlancheTraceeText(
          body,
          session,
          members,
          visitors,
          dignitaries,
          chrono,
        );
  final paragraphs = text
      .split('\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final signatureBytes = _decodeHgSignature(
    session.extra['plancheTfpmSignature'] as String?,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(18 * _mm),
      footer: _footer,
      build: (context) => [
        if (logo != null)
          pw.Center(
            child: pw.SizedBox(
              height: 26 * _mm,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
        pw.SizedBox(height: 4 * _mm),
        pw.Center(
          child: pw.Text(
            hgInstitutionHeader(body),
            style: pw.TextStyle(font: fonts.bold, fontSize: 14, color: _navy),
          ),
        ),
        pw.SizedBox(height: 8 * _mm),
        pw.Center(
          child: pw.Text(
            'PLANCHE TRACÉE — Tenue n°$chrono',
            style: pw.TextStyle(font: fonts.bold, fontSize: 15, color: _navy),
          ),
        ),
        pw.SizedBox(height: 10 * _mm),
        if (paragraphs.isEmpty)
          pw.Text(
            'Planche tracée non rédigée.',
            style: pw.TextStyle(
              font: fonts.base,
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          )
        else
          for (final p in paragraphs)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 3 * _mm),
              child: pw.Text(
                p,
                style: pw.TextStyle(
                  font: fonts.base,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ),
        pw.SizedBox(height: 14 * _mm),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Trois Fois Puissant Maître',
                style: pw.TextStyle(font: fonts.base, fontSize: 9.5),
              ),
              pw.Text(
                signerName,
                style: pw.TextStyle(font: fonts.bold, fontSize: 11),
              ),
              if (signatureBytes != null) ...[
                pw.SizedBox(height: 2 * _mm),
                pw.SizedBox(
                  height: 18 * _mm,
                  width: 45 * _mm,
                  child: pw.Image(
                    pw.MemoryImage(signatureBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

// ══════════════════════════════════════════════════════════════════
// PAIEMENT DES AGAPES — même principe que buildAgapePaymentPdf
// (pdf_service.dart, loges bleues), gabarit visuel propre à IAH-MES.
// ══════════════════════════════════════════════════════════════════

String _formatHgAmount(num value) {
  final s = value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');
  return '$s €';
}

/// Feuille de paiement des agapes d'une tenue de Hauts Grades : chaque
/// payeur signe le règlement de sa médaille, le total encaissé figure en
/// bas du tableau — réutilise agape_payment_service.dart tel quel (pur,
/// indépendant de LodgeConfig une fois memberObedience/memberLodge fournis).
Future<Uint8List> buildIahMesAgapePaymentPdf(
  HgBody body,
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) async {
  final fonts = await _loadFonts();
  final logo = await _loadImage(_logoAsset(body));
  final doc = pw.Document(
    author: 'Grande Loge de Bourbon (GLDB) — N° RNA W9R2011523',
  );

  final payers = agapePayers(
    session,
    members,
    visitors,
    dignitaries,
    memberObedience: 'GLDB',
    memberLodge: body.label,
  );
  final signatures = session.agapePaymentSignatures;
  final amount = agapeMedailleAmount(session);
  final total = agapeCollectedTotal(session, members, visitors, dignitaries);
  final sessionNumber =
      session.chrono?.toInt().toString() ?? session.sessionNumber ?? '';

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
      footer: _footer,
      theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
      build: (context) => [
        if (logo != null)
          pw.Center(
            child: pw.SizedBox(
              height: 26 * _mm,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
        pw.SizedBox(height: 4 * _mm),
        pw.Center(
          child: pw.Text(
            hgInstitutionHeader(body),
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
          'Tenue N° $sessionNumber du ${_formatDateLong(session.date)}'
          ' — médaille : ${_formatHgAmount(amount)}',
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
                  _hgCell(fonts, maskPersonName(p.lastName), 10 * _mm),
                  _hgCell(fonts, maskPersonName(p.firstName), 10 * _mm),
                  _hgCell(fonts, p.obedience, 10 * _mm),
                  _hgCell(fonts, p.lodge, 10 * _mm),
                  _hgCell(fonts, _formatHgAmount(amount), 10 * _mm),
                  _hgSignatureCell(
                    _decodeHgSignature(signatures[p.id]),
                    10 * _mm,
                  ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total encaissé : ${_formatHgAmount(total)}',
            style: pw.TextStyle(font: fonts.bold, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
