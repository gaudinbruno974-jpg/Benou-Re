// Génération PDF pour les corps de Hauts Grades (IAH-MES pour l'instant) —
// fichier séparé de pdf_service.dart (dédié aux 4 loges bleues) : le
// gabarit de convocation d'un Collège de Perfection n'a presque rien de
// commun avec celui d'une tenue de loge bleue (voir les PDF fournis par
// l'utilisateur en référence — ordre du jour figé, pas de planche d'un
// membre nommé mais un « thème de la tenue », signataire « Trois Fois
// Puissant Maître »...). Recopie volontairement quelques utilitaires de
// pdf_service.dart (polices, pied de page) plutôt que de les exposer
// publiquement depuis ce fichier partagé par les 4 loges bleues.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show imageFromAssetBundle;

import '../models/hg_session.dart';

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

/// Convocation d'une tenue du Collège de Perfection IAH-MES — voir
/// hg_session.dart pour les champs variables, le reste du gabarit est fixe
/// (confirmé sur les exemples fournis par l'utilisateur).
Future<Uint8List> buildIahMesConvocationPdf(HgSession session) async {
  final fonts = await _loadFonts();
  final logoIahMes = await _loadImage('assets/Iah-Mes.jfif');
  final logoGldb = await _loadImage('assets/GLDB.png');
  final degreeName = kIahMesDegreeNames[session.degree] ?? '';
  final lieu = session.lieu.trim().isEmpty
      ? 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre'
      : session.lieu.trim();

  final doc = pw.Document(
    author: 'Grande Loge de Bourbon (GLDB) — N° RNA W9R2011523',
  );

  pw.Widget logoBox(pw.ImageProvider? img) => pw.SizedBox(
    width: 24 * _mm,
    height: 24 * _mm,
    child: img == null ? pw.SizedBox() : pw.Image(img, fit: pw.BoxFit.contain),
  );

  pw.Widget bullet(String text) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 1.5 * _mm, left: 4 * _mm),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('•  ', style: pw.TextStyle(font: fonts.base, fontSize: 10)),
        pw.Expanded(
          child: pw.Text(
            text,
            style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
          ),
        ),
      ],
    ),
  );

  pw.Widget agendaTitle(String text) => pw.Padding(
    padding: pw.EdgeInsets.only(top: 3 * _mm, bottom: 1.5 * _mm),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: fonts.bold, fontSize: 11, color: _navy),
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
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: pw.EdgeInsets.only(top: 2 * _mm),
            child: pw.Text(
              'A∴L∴G∴D∴S∴A∴D∴M∴',
              style: pw.TextStyle(font: fonts.bold, fontSize: 9),
            ),
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
            logoBox(logoGldb),
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
          'Correspondance : Trois Fois Puissant Maître ${session.signerName}\n'
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
          'IAH-MES, au ${session.degree}e degré, qui se tiendra :',
          style: pw.TextStyle(font: fonts.base, fontSize: 10.5, height: 1.4),
        ),
        pw.SizedBox(height: 4 * _mm),
        pw.Text(
          '${_formatDateLong(session.date)} à ${session.heure}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fonts.bold, fontSize: 12, color: _navy),
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
        agendaTitle('1. Ouverture des Travaux'),
        pw.Text(
          'Ouverture de la rencontre au ${session.degree}e degré, au Grade '
          'de $degreeName, selon les usages et traditions de notre Ordre.',
          style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
        ),
        agendaTitle('2. Lecture de l\'Ordre du Jour'),
        agendaTitle('3. Appel des FF∴ et SS∴ du Collège'),
        agendaTitle('4. Travail collectif'),
        if (session.themeTitle.trim().isNotEmpty) ...[
          pw.Text(
            'Thème de la Tenue',
            style: pw.TextStyle(font: fonts.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 1 * _mm),
          pw.Text(
            session.themeTitle.trim(),
            style: pw.TextStyle(font: fonts.bold, fontSize: 10.5, color: _navy),
          ),
          if (session.themeText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 1.5 * _mm),
            pw.Text(
              session.themeText.trim(),
              style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.4),
            ),
          ],
          pw.SizedBox(height: 3 * _mm),
        ],
        pw.Text(
          'Rappel concernant le travail collectif',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10),
        ),
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          'La parole circule et chacun est invité à prendre part aux '
          'échanges :',
          style: pw.TextStyle(font: fonts.base, fontSize: 10, height: 1.35),
        ),
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          'Quisque debet loqui « Que chacun puisse parler. »',
          style: pw.TextStyle(
            font: fonts.base,
            fontStyle: pw.FontStyle.italic,
            fontSize: 9.5,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2 * _mm),
        bullet('Le temps de parole sera adapté au nombre de participants ;'),
        bullet('Chaque S∴ ou F∴ pourra intervenir librement ;'),
        bullet('Les interventions pourront être orales ou écrites ;'),
        bullet(
          'L\'écoute fraternelle et le respect de la parole de chacun '
          'seront privilégiés.',
        ),
        agendaTitle('5. Questions diverses'),
        agendaTitle('6. Fermeture des Travaux'),
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
        pw.SizedBox(height: 1.5 * _mm),
        pw.Text(
          'Participation aux agapes : ${session.agapePrice} €',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10),
        ),
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
                session.signerName,
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
