// Lecture/écriture minimale de classeurs .xlsx (OOXML SpreadsheetML), sans le
// paquet `excel` — incompatible avec `pdf` (déjà utilisé pour les documents
// PDF de l'app) : les deux exigent des versions de `xml` qui s'excluent
// mutuellement. Ce module se limite à ce dont l'export/import
// Membres/Visiteurs/Dignitaires a besoin : plusieurs feuilles, des cellules
// texte, une ligne d'en-tête — pas de mise en forme, pas de formules.
//
// L'écriture n'utilise que des gabarits de chaînes (le contenu variable est
// échappé à la main) ; la lecture s'appuie sur `package:xml`, une dépendance
// stable déjà tirée par `pdf`.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Construit un classeur .xlsx : une feuille par entrée de [sheets] (nom de
/// feuille -> lignes de cellules texte, la première ligne étant l'en-tête).
List<int> buildXlsx(Map<String, List<List<String>>> sheets) {
  final names = sheets.keys.toList();
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('[Content_Types].xml', _contentTypesXml(names.length));
  add('_rels/.rels', _rootRelsXml);
  add('xl/workbook.xml', _workbookXml(names));
  add('xl/_rels/workbook.xml.rels', _workbookRelsXml(names.length));
  add('xl/styles.xml', _stylesXml);
  for (var i = 0; i < names.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[names[i]]!));
  }

  final zip = ZipEncoder().encode(archive);
  return zip;
}

/// Lit un classeur .xlsx et renvoie, pour chaque nom demandé dans
/// [sheetNames] (comparaison insensible à la casse), ses lignes de cellules
/// texte. Une feuille demandée mais absente du fichier n'apparaît pas dans le
/// résultat.
Map<String, List<List<String>>> readXlsx(
  List<int> bytes,
  List<String> sheetNames,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? find(String path) {
    for (final f in archive.files) {
      if (f.name == path) return f;
    }
    return null;
  }

  String? contentOf(String path) {
    final f = find(path);
    if (f == null || !f.isFile) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final result = <String, List<List<String>>>{};
  final workbookXml = contentOf('xl/workbook.xml');
  final relsXml = contentOf('xl/_rels/workbook.xml.rels');
  if (workbookXml == null || relsXml == null) return result;

  final ridToTarget = <String, String>{};
  for (final rel in XmlDocument.parse(relsXml).findAllElements('Relationship')) {
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) ridToTarget[id] = target;
  }

  final sharedStrings = _readSharedStrings(contentOf('xl/sharedStrings.xml'));

  for (final sheetEl in XmlDocument.parse(workbookXml).findAllElements('sheet')) {
    final name = (sheetEl.getAttribute('name') ?? '').trim();
    final matched = sheetNames.firstWhere(
      (n) => n.toLowerCase() == name.toLowerCase(),
      orElse: () => '',
    );
    if (matched.isEmpty) continue;
    final rid = _localAttr(sheetEl, 'id');
    final target = rid == null ? null : ridToTarget[rid];
    if (target == null) continue;
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final sheetXml = contentOf(path);
    if (sheetXml == null) continue;
    result[matched] = _parseSheetRows(sheetXml, sharedStrings);
  }
  return result;
}

/// Valeur d'un attribut par son nom local, indépendamment de son préfixe
/// d'espace de noms (« r:id » et « id » sont tous deux trouvés par `id`) —
/// évite de dépendre du traitement des préfixes du paquet `xml`.
String? _localAttr(XmlElement el, String local) {
  for (final a in el.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

String _escapeXmlText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    switch (rune) {
      case 38:
        buffer.write('&amp;');
      case 60:
        buffer.write('&lt;');
      case 62:
        buffer.write('&gt;');
      default:
        // XML 1.0 interdit la plupart des caractères de contrôle, à
        // l'exception de tabulation/LF/CR.
        if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
          continue;
        }
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

String _colLetter(int index) {
  var n = index + 1;
  var s = '';
  while (n > 0) {
    final rem = (n - 1) % 26;
    s = String.fromCharCode(65 + rem) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

int _colIndexFromRef(String ref) {
  var col = 0;
  for (final ch in ref.runes) {
    if (ch >= 65 && ch <= 90) {
      col = col * 26 + (ch - 64);
    } else {
      break;
    }
  }
  return col - 1;
}

String _sheetXml(List<List<String>> rows) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );
  for (var r = 0; r < rows.length; r++) {
    buffer.write('<row r="${r + 1}">');
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final cellRef = '${_colLetter(c)}${r + 1}';
      final value = _escapeXmlText(row[c]);
      buffer.write(
        '<c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$value</t></is></c>',
      );
    }
    buffer.write('</row>');
  }
  buffer.write('</sheetData></worksheet>');
  return buffer.toString();
}

String _contentTypesXml(int sheetCount) {
  final overrides = StringBuffer();
  for (var i = 1; i <= sheetCount; i++) {
    overrides.write(
      '<Override PartName="/xl/worksheets/sheet$i.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '$overrides'
      '</Types>';
}

const String _rootRelsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbookXml(List<String> names) {
  final sheetsXml = StringBuffer();
  for (var i = 0; i < names.length; i++) {
    sheetsXml.write(
      '<sheet name="${_escapeXmlText(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    );
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>$sheetsXml</sheets>'
      '</workbook>';
}

String _workbookRelsXml(int sheetCount) {
  final rels = StringBuffer();
  for (var i = 1; i <= sheetCount; i++) {
    rels.write(
      '<Relationship Id="rId$i" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$i.xml"/>',
    );
  }
  final stylesRid = sheetCount + 1;
  rels.write(
    '<Relationship Id="rId$stylesRid" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/>',
  );
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '$rels'
      '</Relationships>';
}

const String _stylesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

List<String> _readSharedStrings(String? xml) {
  if (xml == null) return const [];
  final doc = XmlDocument.parse(xml);
  return doc.findAllElements('si').map((si) {
    return si.findAllElements('t').map((t) => t.innerText).join();
  }).toList();
}

List<List<String>> _parseSheetRows(String xml, List<String> sharedStrings) {
  final doc = XmlDocument.parse(xml);
  final rows = <List<String>>[];
  for (final rowEl in doc.findAllElements('row')) {
    final cells = <int, String>{};
    var maxCol = -1;
    for (final cellEl in rowEl.findElements('c')) {
      final ref = cellEl.getAttribute('r') ?? '';
      final colIndex = _colIndexFromRef(ref);
      if (colIndex < 0) continue;
      final type = cellEl.getAttribute('t');
      String value;
      if (type == 'inlineStr') {
        final isEls = cellEl.findElements('is');
        final tEls = isEls.isEmpty ? null : isEls.first.findElements('t');
        value = (tEls == null || tEls.isEmpty) ? '' : tEls.first.innerText;
      } else if (type == 's') {
        final vEls = cellEl.findElements('v');
        final vText = vEls.isEmpty ? '' : vEls.first.innerText;
        final idx = int.tryParse(vText);
        value = (idx != null && idx >= 0 && idx < sharedStrings.length)
            ? sharedStrings[idx]
            : '';
      } else {
        final vEls = cellEl.findElements('v');
        if (vEls.isNotEmpty) {
          value = vEls.first.innerText;
        } else {
          final isEls = cellEl.findElements('is');
          value = isEls.isEmpty ? '' : isEls.first.innerText;
        }
      }
      cells[colIndex] = value;
      if (colIndex > maxCol) maxCol = colIndex;
    }
    rows.add(List<String>.generate(maxCol + 1, (i) => cells[i] ?? ''));
  }
  return rows;
}
