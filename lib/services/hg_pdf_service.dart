// Génération PDF pour les corps de Hauts Grades (IAH-MES pour l'instant) —
// fichier séparé de pdf_service.dart (dédié aux 4 loges bleues) : le
// gabarit visuel d'une convocation de Collège de Perfection reste propre à
// IAH-MES (logo, en-tête, signataire « Trois Fois Puissant Maître »...),
// même si le contenu de l'ordre du jour est maintenant, comme pour les
// loges bleues, entièrement piloté par la tenue elle-même (Session —
// demande explicite de l'utilisateur, « copie l'intégralité »). Recopie
// volontairement quelques utilitaires de pdf_service.dart (polices, pied de
// page) plutôt que de les exposer publiquement depuis ce fichier partagé
// par les 4 loges bleues.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show imageFromAssetBundle;

import '../models/hg_session.dart' show kIahMesDegreeNames;
import '../models/session.dart';
import 'pdf_service.dart' show getMasonicDate, getSothiacDate;

const double _mm = PdfPageFormat.mm;
const _navy = PdfColor.fromInt(0xFF0C235C);

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

Future<pw.ImageProvider?> _loadImage(String path) async {
  try {
    return await imageFromAssetBundle(path);
  } catch (_) {
    return null;
  }
}

pw.Widget _footer(pw.Context context) => pw.Container(
  alignment: pw.Alignment.center,
  margin: pw.EdgeInsets.only(top: 4 * _mm),
  child: pw.Text(
    '© Grande Loge de Bourbon (GLDB) - N° RNA W9R2011523',
    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
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
Future<Uint8List> buildIahMesConvocationPdf(Session session) async {
  final fonts = await _loadFonts();
  final logoIahMes = await _loadImage('assets/Iah-Mes.jfif');
  final logoSouverainSanctuaire = await _loadImage(
    'assets/Souverain-Sanctuaire.jfif',
  );
  final degree = _sessionDegree(session);
  final degreeName = kIahMesDegreeNames[degree] ?? '';
  final lieu = (session.lieuReunionExtra ?? '').trim().isEmpty
      ? 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre'
      : session.lieuReunionExtra!.trim();
  final signerName = (session.vmName ?? '').trim().isEmpty
      ? 'Trois Fois Puissant Maître'
      : session.vmName!.trim();
  final masonicDate = getMasonicDate(session.dateTime);
  final sothiacDate = getSothiacDate(session.dateTime);

  final fixedWorks = [
    session.travail1,
    session.travail2,
    session.travail3,
    session.travail4,
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

  pw.Widget numberedLine(int n, String text) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 2 * _mm),
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
          child: pw.Text(
            text,
            style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
          ),
        ),
      ],
    ),
  );

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
        pw.SizedBox(height: 4 * _mm),
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
        pw.SizedBox(height: 5 * _mm),
        pw.Text(
          'COLLÈGE DE PERFECTION IAH-MES N°1\n'
          'Vallée de Saint-Pierre — Temple Thérèse Eliseman',
          style: pw.TextStyle(font: fonts.bold, fontSize: 9),
        ),
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          'Correspondance : Trois Fois Puissant Maître $signerName\n'
          'iahmes.sstr@gmail.com',
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
          style: pw.TextStyle(font: fonts.bold, fontSize: 15, color: _navy),
        ),
        pw.SizedBox(height: 6 * _mm),
        pw.Text(
          'Mes Très Chers FF∴ et Bien-Aimées SS∴,',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10.5),
        ),
        pw.SizedBox(height: 2 * _mm),
        pw.Text(
          'J\'ai le plaisir de vous faire savoir que vous êtes fraternellement '
          'convoqués à la prochaine rencontre de notre Collège de Perfection '
          'IAH-MES, au ${degree}e degré, qui se tiendra :',
          style: pw.TextStyle(font: fonts.base, fontSize: 10.5, height: 1.4),
        ),
        pw.SizedBox(height: 4 * _mm),
        pw.Text(
          '${_formatDateLong(session.date)} à ${_sessionHeure(session)}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 12, color: _navy),
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
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          'Au $lieu',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.base, fontSize: 10.5),
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
        if (cloture.isNotEmpty) ...[
          pw.SizedBox(height: 2 * _mm),
          pw.Text(
            cloture,
            style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
          ),
        ],
        if (session.degreeLabel.isNotEmpty) ...[
          pw.SizedBox(height: 4 * _mm),
          pw.Text(
            'Grade de travail : $degreeName',
            style: pw.TextStyle(
              font: fonts.base,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
        if (session.suitAgapes) ...[
          pw.SizedBox(height: 5 * _mm),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'AGAPES FRATERNELLES',
            style: pw.TextStyle(font: fonts.bold, fontSize: 11, color: _navy),
          ),
          pw.SizedBox(height: 2 * _mm),
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
        pw.SizedBox(height: 10 * _mm),
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
