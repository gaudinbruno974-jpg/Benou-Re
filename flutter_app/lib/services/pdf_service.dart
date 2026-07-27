// Génération des PDF (porté depuis src/lib/plancheTraceePdf.ts et
// src/lib/googleDrive.ts -> generateEmargementPdf).
//
// Deux documents sont produits :
//  - la feuille de présence / émargement (tableau membres + invités) ;
//  - la planche tracée (texte officiel de la tenue + signatures).
//
// Les signatures sont des data URLs base64 stockées dans `session.signatures`
// (et les champs planche* pour la planche tracée).
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';

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

String _degreOrdinal(String? degre) {
  switch (degre) {
    case 'Compagnon':
      return '2ème';
    case 'Maitre':
    case 'Maître':
      return '3ème';
    default:
      return '1er';
  }
}

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
  final source =
      raw.any((r) => (r ?? '').trim().isNotEmpty) ? raw : fallback;
  return source
      .map((item) =>
          (item ?? '').replaceFirst(RegExp(r'^\s*\d+\s*[.)]\s*'), '').trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class _PdfFonts {
  final pw.Font base;
  final pw.Font bold;
  _PdfFonts(this.base, this.bold);
}

Future<_PdfFonts> _loadFonts() async {
  final base = await PdfGoogleFonts.notoSerifRegular();
  final bold = await PdfGoogleFonts.notoSerifBold();
  return _PdfFonts(base, bold);
}

// ══════════════════════════════════════════════════════════════════
// FEUILLE DE PRÉSENCE / ÉMARGEMENT
// ══════════════════════════════════════════════════════════════════
Future<Uint8List> buildEmargementPdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
) async {
  final fonts = await _loadFonts();
  final doc = pw.Document();

  final signatures = session.signatures;
  final type = session.type.isNotEmpty ? session.type : 'Ordinaire';
  final degree = session.degree.isNotEmpty ? session.degree : 'Apprenti';
  final sessionNumber = session.sessionNumber ??
      (session.chrono != null ? '${session.chrono}' : '');
  final location = session.location.isNotEmpty
      ? session.location
      : (session.lieuReunionExtra ?? '');
  final dateStr = session.date.isNotEmpty ? session.date : (session.dateReprise ?? '');

  final memberRows = members
      .where((m) => session.presentIds.contains(m.id))
      .map((m) => _Row(
            m.lastName,
            m.firstName,
            m.function != 'Aucun' && m.function.isNotEmpty
                ? m.function
                : 'Membre',
            _lodgeName,
            signatures[m.id],
          ))
      .toList();
  final visitorRows = visitors
      .where((v) => session.visitorIds.contains(v.id))
      .map((v) => _Row(
            v.lastName,
            v.firstName,
            session.visitorRoles[v.id] ??
                (v.function.isNotEmpty ? v.function : 'Visiteur'),
            v.lodge,
            signatures[v.id],
          ))
      .toList();

  pw.Widget header() => pw.Column(children: [
        pw.Text('Respectable Loge Benou Ré',
            style: pw.TextStyle(
                font: fonts.bold, fontSize: 18, color: _violet)),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.black, thickness: 0.4),
        pw.SizedBox(height: 10),
        pw.Text('FEUILLE DE PRÉSENCE',
            style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 22,
                color: _violet,
                letterSpacing: 1)),
        pw.Container(
          width: 160,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _violet, width: 1)),
          ),
        ),
        pw.SizedBox(height: 12),
      ]);

  pw.Widget metaLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: label,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 13)),
              pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(font: fonts.base, fontSize: 13)),
            ],
          ),
        ),
      );

  pw.TableRow sectionRow(String label) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: _grey),
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(label,
                style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
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

  pw.Table dataTable(List<_Row?> rows) {
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
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(h,
                    style: pw.TextStyle(font: fonts.bold, fontSize: 11)),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              _cell(fonts, row?.lastName),
              _cell(fonts, row?.firstName),
              _cell(fonts, row?.role),
              _cell(fonts, row?.lodge),
              _signatureCell(_decodeSignature(row?.signature)),
            ],
          ),
      ],
    );
  }

  final memberSlots = List<_Row?>.generate(
      20, (i) => i < memberRows.length ? memberRows[i] : null);
  final visitorSlots = List<_Row?>.generate(
      5, (i) => i < visitorRows.length ? visitorRows[i] : null);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    build: (context) => [
      header(),
      metaLine('Objet : ', "Tenue $type – Grade d'$degree"),
      metaLine('Fiche N° : ', sessionNumber),
      metaLine('Date : ', _formatDateFrench(dateStr)),
      metaLine('Lieu : ', location),
      pw.SizedBox(height: 14),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        children: [sectionRow('MEMBRES DE LA LOGE')],
      ),
      dataTable(memberSlots),
      pw.SizedBox(height: 16),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        children: [sectionRow('INVITÉS')],
      ),
      dataTable(visitorSlots),
    ],
  ));

  return doc.save();
}

pw.Widget _cell(_PdfFonts fonts, String? value) => pw.Container(
      height: 22,
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.Text(value ?? '',
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(font: fonts.base, fontSize: 10)),
    );

pw.Widget _signatureCell(Uint8List? bytes) => pw.Container(
      height: 22,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(2),
      child: bytes == null
          ? pw.SizedBox()
          : pw.Image(pw.MemoryImage(bytes), height: 18, fit: pw.BoxFit.contain),
    );

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
Future<Uint8List> buildPlancheTraceePdf(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  int chrono,
) async {
  final fonts = await _loadFonts();
  final doc = pw.Document();

  String memberFullName(Member m) => '${m.firstName} ${m.lastName}'.trim();
  String visitorFullName(Visitor v) => '${v.firstName} ${v.lastName}'.trim();

  final vmName = session.vmName?.isNotEmpty == true ? session.vmName! : 'Bruno GAUDIN';
  final dateFR = _formatDateFR(session.dateReprise ?? session.date);
  final degre = _degreOrdinal(session.degreTravail ?? session.degree);

  final content = <pw.Widget>[];

  pw.Widget para(String text,
      {double size = 10,
      bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor color = PdfColors.black,
      double gap = 4}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: gap),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
            font: bold ? fonts.bold : fonts.base, fontSize: size, color: color),
      ),
    );
  }

  content.add(para(
      'Planche Tracée de la Tenue Régulière N°$chrono du $dateFR',
      size: 13, bold: true, align: pw.TextAlign.center, color: _navy, gap: 2));
  content.add(para(
      'De la Respectable Loge BENOU RE N°5 à l’Orient Saint-Pierre',
      size: 11, bold: true, align: pw.TextAlign.center, color: _navy, gap: 8));
  content.add(para(
      'Vénérable Maître en chaire et vous tous mes Frères et Sœurs en vos grades et qualités.',
      size: 10, gap: 6));
  content.add(para(
      'Protocole de la Tenue ${session.type == 'Solennelle' ? 'Solennelle' : (session.typeTenue ?? (session.type.isNotEmpty ? session.type : 'Régulière'))} du $dateFR de Ère Vulgaire.',
      size: 10, bold: true, gap: 6));
  content.add(para(
      'Les Membres composant la Respectable Loge BENOU RE N°5 régulièrement Convoqués, sont traditionnellement réunis en un lieu très pur, très saint et très éclairé par la lumière d’Egypte, lieu où règne la Paix, la Joie et l’Harmonie.',
      size: 10, gap: 6));
  content.add(para(
      'Les Sœurs et Frères sont éclairés à l’orient par la sagesse du V∴ M∴ en chaire $vmName.',
      size: 10, gap: 6));
  content.add(para(
      'Les Sœurs et Frères dont le nom figure sur le registre des présences, nous ont fait la joie d’assister à nos travaux.',
      size: 10, gap: 6));

  // Membres excusés
  final excused = session.excusedIds
      .map((id) => members.where((m) => m.id == id).firstOrNull)
      .whereType<Member>()
      .toList();
  if (excused.isNotEmpty) {
    final noms = excused.map(memberFullName).join(', ');
    content.add(para(
        '$noms membre(s) de la R∴ L∴ Bénou Ré sont absents excusés. (Voir la liste des membres excusés)',
        size: 10, gap: 6));
  } else {
    content.add(para('Aucun membre de la R∴ L∴ Bénou Ré n’est absent excusé.',
        size: 10, gap: 6));
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
    final who = 'le F∴ S∴ ${visitorFullName(v)} (${v.lodge})';
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

  final dignitairesOrient = presentVisitors.where((v) =>
      placementOf(v) == 'Orient' &&
      roleOf(v) != 'Orateur' &&
      isOffice(roleOf(v) ?? '')).toList();
  if (dignitairesOrient.isNotEmpty) {
    final liste = dignitairesOrient
        .map((v) => '${visitorFullName(v)} (${roleOf(v)} – ${v.lodge})')
        .join(', ');
    content.add(para(
        'A l’Orient, sont venus soutenir nos travaux les dignitaires suivants : $liste.',
        size: 10, gap: 6));
  }

  final orateurMember = members.where((m) =>
      m.function.trim() == 'Orateur' &&
      session.presentIds.contains(m.id)).firstOrNull;
  final orateurVisitor =
      presentVisitors.where((v) => roleOf(v) == 'Orateur').firstOrNull;
  final orateurName = session.plancheOrateurName?.isNotEmpty == true
      ? session.plancheOrateurName
      : (orateurMember != null
          ? memberFullName(orateurMember)
          : (orateurVisitor != null ? visitorFullName(orateurVisitor) : null));
  content.add(para(
      orateurName != null
          ? 'Le poste d’Orateur est occupé par le F∴ S∴ $orateurName.'
          : 'Le poste d’Orateur est resté vide.',
      size: 10, gap: 6));

  for (final v in presentVisitors) {
    final role = roleOf(v);
    final placement = placementOf(v);
    if (role == 'Orateur') continue;
    if (placement == 'Orient' && isOffice(role ?? '')) continue;
    if (placement != null) {
      content.add(para(placementSentence(v, placement, role as String),
          size: 10, gap: 3));
    } else {
      content.add(para(
          'Le F∴ S∴ ${visitorFullName(v)} (${v.lodge} – Orient de ${v.orient}) a pris place sur les Colonnes, selon la feuille de présence.',
          size: 10, gap: 3));
    }
  }

  content.add(pw.SizedBox(height: 3));
  content.add(
      para('La planche tracée de nos derniers travaux a été adoptée.', size: 10, gap: 6));

  // Ordre du jour traité
  content.add(para('L’ordre du jour de la Tenue a appelé :',
      size: 11, bold: true, gap: 5));
  final items = _collectOrdreDuJour(session);
  final notes = session.plancheTravauxNotes;
  for (var idx = 0; idx < items.length; idx++) {
    content.add(pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('${idx + 1}. ',
              style: pw.TextStyle(font: fonts.base, fontSize: 10)),
          pw.Expanded(
            child: pw.Text(items[idx],
                style: pw.TextStyle(font: fonts.base, fontSize: 10)),
          ),
        ],
      ),
    ));
    final note = (idx < notes.length ? notes[idx] : '').trim();
    if (note.isNotEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
        child: pw.Text(note,
            style: pw.TextStyle(
                font: fonts.base,
                fontSize: 9.5,
                color: const PdfColor.fromInt(0xFF464646))),
      ));
    }
  }
  content.add(pw.SizedBox(height: 4));

  // Tronc de la veuve
  final tronc = session.troncAmount.toDouble();
  final euros = tronc.floor();
  final centimes = ((tronc - euros) * 100).round();
  content.add(para(
      'L’ordre du jour étant épuisé, le V∴ M∴ fait circuler le Tronc de la veuve et le Sac aux Propositions. Ce dernier revient pur et sans tache. Le Tronc revient lourd de $euros Pierre(s) Plate(s) et $centimes Morceau(x) d’éclats, qui ont été pris en charge par le Trésorier.',
      size: 10, gap: 6));

  content.add(para(
      'Les Travaux sont ensuite fermés au $degre degré symbolique. Au cours de ce Cérémonial, les Sœurs et les Frères forment une Chaîne d’Union Fraternelle, selon le Rite, puis se séparent en jurant de garder le Silence sur les Travaux de ce Jour.',
      size: 10, gap: 8));
  content.add(para('J’ai dit Vénérable Maître,', size: 10, bold: true, gap: 10));

  // Signatures
  final secretaryMember = members.where((m) =>
      m.function.trim() == 'Secrétaire' &&
      session.presentIds.contains(m.id)).firstOrNull;
  final secretaryName =
      secretaryMember != null ? memberFullName(secretaryMember) : '';
  final sigs = <List<String?>>[
    ['Le Frère Orateur', orateurName, session.plancheOrateurSignature],
    ['Le Vénérable Maître', vmName, session.plancheVMSignature],
    ['La Sœur Secrétaire', secretaryName, session.plancheSecretarySignature],
  ];
  content.add(pw.SizedBox(height: 10));
  content.add(pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final s in sigs)
        pw.Expanded(
          child: pw.Column(children: [
            pw.Text(s[0]!,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: fonts.bold, fontSize: 9.5, color: _navy)),
            pw.SizedBox(height: 3),
            pw.SizedBox(
              height: 20,
              child: _decodeSignature(s[2]) == null
                  ? pw.SizedBox()
                  : pw.Image(pw.MemoryImage(_decodeSignature(s[2])!),
                      fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 3),
            pw.Text(s[1] ?? '',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fonts.base, fontSize: 9)),
          ]),
        ),
    ],
  ));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(15),
    build: (context) => content,
  ));

  return doc.save();
}
