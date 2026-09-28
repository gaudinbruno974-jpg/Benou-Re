// Export / import groupé des répertoires Membres, Visiteurs, Dignitaires en
// un classeur .xlsx à trois onglets (voir xlsx_codec.dart pour la lecture/
// écriture du fichier lui-même). Détecte les doublons par nom+prénom pour
// permettre, à l'import, de choisir ligne par ligne entre création, mise à
// jour d'une fiche existante, ou ignorer.
import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import 'xlsx_codec.dart';

const String kSheetMembers = 'Membres';
const String kSheetVisitors = 'Visiteurs';
const String kSheetDignitaries = 'Dignitaires';

const List<String> kMemberHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
  'Grade',
  'Office',
  'Statut',
  'Email',
  'Téléphone',
  'Adresse',
  'Matricule',
  'Loge mère',
  'Parrain',
  'Canal préféré',
  'Date de naissance',
  "Date d'initiation",
  "Date d'entrée",
  'Cotisation Loge',
  'Cotisation Ordre',
];

const List<String> kVisitorHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
  'Grade',
  'Fonction',
  "Loge d'origine",
  'Orient',
  'Obédience',
  'Email',
  'Téléphone',
];

const List<String> kDignitaryHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
  'Titre / qualité',
  "Loge d'origine",
  'Orient',
  'Obédience',
  'Email',
  'Téléphone',
  'Canal préféré',
  'Rang protocolaire',
];

String _cell(List<String> row, int i) => i < row.length ? row[i].trim() : '';

/// Nombre sans « ,0 » superflu pour un montant entier (ex. « 100 » plutôt
/// que « 100.0 »), tel qu'on l'attend dans une colonne de tableur.
String _formatNum(num v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

num? _tryParseNum(String v) {
  if (v.trim().isEmpty) return null;
  return num.tryParse(v.trim().replaceAll(',', '.'));
}

/// Clé de rapprochement pour la détection de doublon : nom + prénom,
/// insensible à la casse et aux accents (même convention que la recherche
/// des répertoires, voir directory_filter.dart).
String nameKey(String firstName, String lastName) =>
    foldLabel('$firstName $lastName');

// ─── Export ───────────────────────────────────────────────────────────

List<List<String>> _memberRows(List<Member> members) => [
  kMemberHeaders,
  for (final m in members)
    [
      m.civilite,
      m.firstName,
      m.lastName,
      m.grade,
      m.function,
      m.status,
      m.email,
      m.phone,
      m.address,
      m.matricule,
      m.motherLodge,
      m.sponsor,
      m.preferredContact,
      m.birthDate,
      m.initiationDate,
      m.entryDate,
      // Cotisation de l'année en cours (voir Member.duesFor) : mêmes montants
      // que ceux affichés par défaut sur l'écran Trésorerie.
      _formatNum(m.duesFor(DateTime.now().year).lodgeDues),
      _formatNum(m.duesFor(DateTime.now().year).orderDues),
    ],
];

List<List<String>> _visitorRows(List<Visitor> visitors) => [
  kVisitorHeaders,
  for (final v in visitors)
    [
      v.civilite,
      v.firstName,
      v.lastName,
      v.grade,
      v.function,
      v.lodge,
      v.orient,
      v.obedience,
      v.email,
      v.phone,
    ],
];

List<List<String>> _dignitaryRows(List<Dignitary> dignitaries) => [
  kDignitaryHeaders,
  for (final d in dignitaries)
    [
      d.civilite,
      d.firstName,
      d.lastName,
      d.title,
      d.lodge,
      d.orient,
      d.obedience,
      d.email,
      d.phone,
      d.preferredContact,
      d.protocolRank?.toString() ?? '',
    ],
];

/// Classeur complet (données réelles) des trois répertoires.
List<int> buildDirectoryWorkbook({
  required List<Member> members,
  required List<Visitor> visitors,
  required List<Dignitary> dignitaries,
}) {
  return buildXlsx({
    kSheetMembers: _memberRows(members),
    kSheetVisitors: _visitorRows(visitors),
    kSheetDignitaries: _dignitaryRows(dignitaries),
  });
}

/// Répertoires d'une loge, pour l'export groupé de la Grande Loge.
class LodgeDirectory {
  final String lodgeName;
  final List<Member> members;
  final List<Visitor> visitors;
  final List<Dignitary> dignitaries;
  const LodgeDirectory({
    required this.lodgeName,
    required this.members,
    required this.visitors,
    required this.dignitaries,
  });
}

int _byName(String lastA, String firstA, String lastB, String firstB) {
  final c = foldLabel(lastA).compareTo(foldLabel(lastB));
  return c != 0 ? c : foldLabel(firstA).compareTo(foldLabel(firstB));
}

// ─── Normalisation / détection d'incohérences (export + sync Grande Loge) ──
// Conventions attendues sur les répertoires des 4 loges bleues (voir la
// correction faite à la main en base le 2026-09-28) : téléphone au format
// « +262 XXX XX XX XX », nom de famille en MAJUSCULES, prénom en casse
// normale. [normalizePhoneNumber]/[normalizeTitleCase] calculent la valeur
// corrigée (utilisées par grande_loge_directory_sync.dart pour écrire la
// correction) ; les fonctions `_is...Ok` ci-dessous ne font que comparer à
// cette même valeur, pour que détection et correction ne divergent jamais.
// L'export lui-même ne modifie jamais les bases, il ne fait que lister.

final RegExp _nonDigits = RegExp(r'\D');

/// Normalise un numéro au format « +262 XXX XX XX XX » quand c'est possible
/// (9 chiffres après retrait de l'indicatif éventuel et d'un 0 initial
/// éventuel) ; renvoie [raw] inchangé sinon (format inattendu, à vérifier à
/// la main plutôt que de deviner).
String normalizePhoneNumber(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  var digits = trimmed.replaceAll(_nonDigits, '');
  if (digits.startsWith('262')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length != 9) return raw;
  return '+262 ${digits.substring(0, 3)} ${digits.substring(3, 5)} '
      '${digits.substring(5, 7)} ${digits.substring(7, 9)}';
}

/// Met en casse normale (chaque mot commence par une majuscule) en
/// préservant espaces et traits d'union (« jean luc » -> « Jean Luc »,
/// « marie-claude » -> « Marie-Claude »).
String normalizeTitleCase(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return raw;
  final buffer = StringBuffer();
  var atWordStart = true;
  for (final rune in t.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == ' ' || ch == '-') {
      buffer.write(ch);
      atWordStart = true;
    } else {
      buffer.write(atWordStart ? ch.toUpperCase() : ch.toLowerCase());
      atWordStart = false;
    }
  }
  return buffer.toString();
}

bool _isValidPhone(String phone) {
  final t = phone.trim();
  return t.isEmpty || t == normalizePhoneNumber(t);
}

bool _isUpperCaseOk(String s) => s.trim().isEmpty || s == s.toUpperCase();

bool _isTitleCaseOk(String s) {
  final t = s.trim();
  return t.isEmpty || t == normalizeTitleCase(t);
}

const List<String> kInconsistencyHeaders = [
  'Loge',
  'Répertoire',
  'Prénom',
  'Nom',
  'Problème',
  'Valeur actuelle',
];

List<List<String>> _inconsistencyRows(List<LodgeDirectory> lodges) {
  final rows = <List<String>>[];

  void check(
    String lodgeName,
    String category,
    String firstName,
    String lastName,
    String phone,
  ) {
    if (!_isValidPhone(phone)) {
      rows.add([
        lodgeName,
        category,
        firstName,
        lastName,
        'Téléphone pas au format +262 XXX XX XX XX',
        phone,
      ]);
    }
    if (!_isUpperCaseOk(lastName)) {
      rows.add([
        lodgeName,
        category,
        firstName,
        lastName,
        'Nom pas en MAJUSCULES',
        lastName,
      ]);
    }
    if (!_isTitleCaseOk(firstName)) {
      rows.add([
        lodgeName,
        category,
        firstName,
        lastName,
        'Prénom pas en casse normale',
        firstName,
      ]);
    }
  }

  void checkDuplicates(
    String lodgeName,
    String category,
    List<(String, String)> names,
  ) {
    final counts = <String, int>{};
    for (final (first, last) in names) {
      final key = foldLabel('$first $last');
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final flagged = <String>{};
    for (final (first, last) in names) {
      final key = foldLabel('$first $last');
      if ((counts[key] ?? 0) > 1 && flagged.add(key)) {
        rows.add([
          lodgeName,
          category,
          first,
          last,
          'Doublon probable (${counts[key]} fiches) dans ce répertoire',
          '',
        ]);
      }
    }
  }

  for (final lodge in lodges) {
    for (final m in lodge.members) {
      check(lodge.lodgeName, kSheetMembers, m.firstName, m.lastName, m.phone);
    }
    checkDuplicates(lodge.lodgeName, kSheetMembers, [
      for (final m in lodge.members) (m.firstName, m.lastName),
    ]);
    for (final v in lodge.visitors) {
      check(lodge.lodgeName, kSheetVisitors, v.firstName, v.lastName, v.phone);
    }
    checkDuplicates(lodge.lodgeName, kSheetVisitors, [
      for (final v in lodge.visitors) (v.firstName, v.lastName),
    ]);
    for (final d in lodge.dignitaries) {
      check(
        lodge.lodgeName,
        kSheetDignitaries,
        d.firstName,
        d.lastName,
        d.phone,
      );
    }
    checkDuplicates(lodge.lodgeName, kSheetDignitaries, [
      for (final d in lodge.dignitaries) (d.firstName, d.lastName),
    ]);
  }
  return rows;
}

/// Classeur groupé des répertoires de plusieurs loges (export de la Grande
/// Loge) : mêmes trois onglets que [buildDirectoryWorkbook], avec une colonne
/// « Loge bleue » en tête (la loge dont le répertoire contient la fiche),
/// triés par loge (dans l'ordre fourni) puis par nom, plus un 4e onglet
/// « Incohérences » qui relève (sans rien corriger) les téléphones, casses de
/// nom et doublons probables à vérifier — voir [_inconsistencyRows].
/// L'onglet Membres ajoute le degré aux Hauts Grades en dernière colonne.
/// Sens unique : ce classeur n'est pas prévu pour être réimporté.
List<int> buildMultiLodgeDirectoryWorkbook(List<LodgeDirectory> lodges) {
  final members = <List<String>>[
    ['Loge bleue', ...kMemberHeaders, 'Degré Hauts Grades'],
  ];
  final visitors = <List<String>>[
    ['Loge bleue', ...kVisitorHeaders],
  ];
  final dignitaries = <List<String>>[
    ['Loge bleue', ...kDignitaryHeaders],
  ];
  for (final lodge in lodges) {
    final sortedMembers = [...lodge.members]
      ..sort(
        (a, b) => _byName(a.lastName, a.firstName, b.lastName, b.firstName),
      );
    for (final m in sortedMembers) {
      members.add([
        lodge.lodgeName,
        ..._memberRows([m])[1],
        m.hautsGradesDegree,
      ]);
    }
    final sortedVisitors = [...lodge.visitors]
      ..sort(
        (a, b) => _byName(a.lastName, a.firstName, b.lastName, b.firstName),
      );
    for (final v in sortedVisitors) {
      visitors.add([
        lodge.lodgeName,
        ..._visitorRows([v])[1],
      ]);
    }
    final sortedDignitaries = [...lodge.dignitaries]
      ..sort(
        (a, b) => _byName(a.lastName, a.firstName, b.lastName, b.firstName),
      );
    for (final d in sortedDignitaries) {
      dignitaries.add([
        lodge.lodgeName,
        ..._dignitaryRows([d])[1],
      ]);
    }
  }
  final inconsistencies = <List<String>>[
    kInconsistencyHeaders,
    ..._inconsistencyRows(lodges),
  ];
  return buildXlsx({
    kSheetMembers: members,
    kSheetVisitors: visitors,
    kSheetDignitaries: dignitaries,
    'Incohérences': inconsistencies,
  });
}

/// Classeur modèle : uniquement les en-têtes, aucune ligne de donnée.
List<int> buildDirectoryTemplate() {
  return buildXlsx({
    kSheetMembers: [kMemberHeaders],
    kSheetVisitors: [kVisitorHeaders],
    kSheetDignitaries: [kDignitaryHeaders],
  });
}

// ─── Import ───────────────────────────────────────────────────────────

enum ImportAction { create, update, skip }

class MemberImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
  final String grade;
  final String function;
  final String status;
  final String email;
  final String phone;
  final String address;
  final String matricule;
  final String motherLodge;
  final String sponsor;
  final String preferredContact;
  final String birthDate;
  final String initiationDate;
  final String entryDate;
  final num? lodgeDues;
  final num? orderDues;
  final Member? existing;
  ImportAction action;

  MemberImportRow({
    required this.civilite,
    required this.firstName,
    required this.lastName,
    required this.grade,
    required this.function,
    required this.status,
    required this.email,
    required this.phone,
    required this.address,
    required this.matricule,
    required this.motherLodge,
    required this.sponsor,
    required this.preferredContact,
    required this.birthDate,
    required this.initiationDate,
    required this.entryDate,
    required this.lodgeDues,
    required this.orderDues,
    required this.existing,
    required this.action,
  });

  /// Fiche telle qu'elle sera écrite, selon [action] — `null` si `skip`.
  ///
  /// Les cotisations (colonnes facultatives) visent l'année en cours,
  /// comme les montants « à plat » du reste de l'application (voir
  /// Member.duesFor) — écrites dans `duesByYear`, seul endroit lu par
  /// l'écran Trésorerie. Colonnes vides : la cotisation n'est pas touchée
  /// (montants déjà versés, dates de règlement... préservés).
  Member? resolve(String Function() newId) {
    final year = DateTime.now().year;
    final hasDues = lodgeDues != null || orderDues != null;
    switch (action) {
      case ImportAction.skip:
        return null;
      case ImportAction.create:
        final member = Member(
          id: newId(),
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          grade: grade.isEmpty ? kApprenti : grade,
          function: function.isEmpty ? 'Aucun' : function,
          status: status.isEmpty ? 'Actif' : status,
          email: email,
          phone: phone,
          address: address,
          matricule: matricule,
          motherLodge: motherLodge,
          sponsor: sponsor,
          preferredContact: preferredContact,
          birthDate: birthDate,
          initiationDate: initiationDate,
          entryDate: entryDate,
        );
        return hasDues
            ? member.withDuesForYear(
                year,
                DuesYear(lodgeDues: lodgeDues ?? 0, orderDues: orderDues ?? 0),
              )
            : member;
      case ImportAction.update:
        final base = existing;
        if (base == null) return null;
        final updated = base.copyWith(
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          grade: grade.isEmpty ? null : grade,
          function: function.isEmpty ? null : function,
          status: status.isEmpty ? null : status,
          email: email,
          phone: phone,
          address: address,
          matricule: matricule,
          motherLodge: motherLodge,
          sponsor: sponsor,
          preferredContact: preferredContact,
          birthDate: birthDate,
          initiationDate: initiationDate,
          entryDate: entryDate,
        );
        if (!hasDues) return updated;
        final dues = updated
            .duesFor(year)
            .copyWith(lodgeDues: lodgeDues, orderDues: orderDues);
        return updated.withDuesForYear(year, dues);
    }
  }
}

class VisitorImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
  final String grade;
  final String function;
  final String lodge;
  final String orient;
  final String obedience;
  final String email;
  final String phone;
  final Visitor? existing;
  ImportAction action;

  VisitorImportRow({
    required this.civilite,
    required this.firstName,
    required this.lastName,
    required this.grade,
    required this.function,
    required this.lodge,
    required this.orient,
    required this.obedience,
    required this.email,
    required this.phone,
    required this.existing,
    required this.action,
  });

  Visitor? resolve(String Function() newId) {
    switch (action) {
      case ImportAction.skip:
        return null;
      case ImportAction.create:
        return Visitor(
          id: newId(),
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          grade: grade,
          function: function,
          lodge: lodge,
          orient: orient,
          obedience: obedience,
          email: email,
          phone: phone,
        );
      case ImportAction.update:
        final base = existing;
        if (base == null) return null;
        return base.copyWith(
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          grade: grade,
          function: function,
          lodge: lodge,
          orient: orient,
          obedience: obedience,
          email: email,
          phone: phone,
        );
    }
  }
}

class DignitaryImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
  final String title;
  final String lodge;
  final String orient;
  final String obedience;
  final String email;
  final String phone;
  final String preferredContact;
  final int? protocolRank;
  final Dignitary? existing;
  ImportAction action;

  DignitaryImportRow({
    required this.civilite,
    required this.firstName,
    required this.lastName,
    required this.title,
    required this.lodge,
    required this.orient,
    required this.obedience,
    required this.email,
    required this.phone,
    required this.preferredContact,
    required this.protocolRank,
    required this.existing,
    required this.action,
  });

  Dignitary? resolve(String Function() newId) {
    switch (action) {
      case ImportAction.skip:
        return null;
      case ImportAction.create:
        return Dignitary(
          id: newId(),
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          title: title,
          lodge: lodge,
          orient: orient,
          obedience: obedience,
          email: email,
          phone: phone,
          preferredContact: preferredContact,
          protocolRank: protocolRank,
        );
      case ImportAction.update:
        final base = existing;
        if (base == null) return null;
        return base.copyWith(
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          title: title,
          lodge: lodge,
          orient: orient,
          obedience: obedience,
          email: email,
          phone: phone,
          preferredContact: preferredContact,
          protocolRank: protocolRank,
          clearProtocolRank: protocolRank == null,
        );
    }
  }
}

/// Catégorie traitée par un écran de répertoire — chaque écran ne lit/écrit
/// que la feuille correspondante d'un classeur importé, même si les autres
/// feuilles sont présentes dans le même fichier.
enum DirectoryCategory { members, visitors, dignitaries }

int? _tryParseInt(String v) => v.trim().isEmpty ? null : int.tryParse(v.trim());

/// Lignes de la feuille « Membres » d'un classeur importé, associées à une
/// fiche existante (nom + prénom) si elle en trouve une, avec une action par
/// défaut (mise à jour pour un doublon détecté, création sinon) —
/// modifiable ensuite ligne par ligne dans l'écran de prévisualisation. Les
/// autres feuilles du classeur, s'il y en a, ne sont pas lues. Les lignes
/// sans prénom ni nom sont ignorées (lignes vides en fin de tableau).
List<MemberImportRow> parseMemberSheet(
  List<int> bytes,
  List<Member> existingMembers,
) {
  final rows = readXlsx(bytes, [kSheetMembers])[kSheetMembers] ?? const [];
  final byKey = {
    for (final m in existingMembers) nameKey(m.firstName, m.lastName): m,
  };
  final result = <MemberImportRow>[];
  for (final row in rows.skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = byKey[nameKey(firstName, lastName)];
    result.add(
      MemberImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        grade: _cell(row, 3),
        function: _cell(row, 4),
        status: _cell(row, 5),
        email: _cell(row, 6),
        phone: _cell(row, 7),
        address: _cell(row, 8),
        matricule: _cell(row, 9),
        motherLodge: _cell(row, 10),
        sponsor: _cell(row, 11),
        preferredContact: _cell(row, 12),
        birthDate: _cell(row, 13),
        initiationDate: _cell(row, 14),
        entryDate: _cell(row, 15),
        lodgeDues: _tryParseNum(_cell(row, 16)),
        orderDues: _tryParseNum(_cell(row, 17)),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}

/// Lignes de la feuille « Visiteurs » d'un classeur importé — voir
/// [parseMemberSheet] pour le principe général.
List<VisitorImportRow> parseVisitorSheet(
  List<int> bytes,
  List<Visitor> existingVisitors,
) {
  final rows = readXlsx(bytes, [kSheetVisitors])[kSheetVisitors] ?? const [];
  final byKey = {
    for (final v in existingVisitors) nameKey(v.firstName, v.lastName): v,
  };
  final result = <VisitorImportRow>[];
  for (final row in rows.skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = byKey[nameKey(firstName, lastName)];
    result.add(
      VisitorImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        grade: _cell(row, 3),
        function: _cell(row, 4),
        lodge: _cell(row, 5),
        orient: _cell(row, 6),
        obedience: _cell(row, 7),
        email: _cell(row, 8),
        phone: _cell(row, 9),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}

/// Lignes de la feuille « Dignitaires » d'un classeur importé — voir
/// [parseMemberSheet] pour le principe général.
List<DignitaryImportRow> parseDignitarySheet(
  List<int> bytes,
  List<Dignitary> existingDignitaries,
) {
  final rows =
      readXlsx(bytes, [kSheetDignitaries])[kSheetDignitaries] ?? const [];
  final byKey = {
    for (final d in existingDignitaries) nameKey(d.firstName, d.lastName): d,
  };
  final result = <DignitaryImportRow>[];
  for (final row in rows.skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = byKey[nameKey(firstName, lastName)];
    result.add(
      DignitaryImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        title: _cell(row, 3),
        lodge: _cell(row, 4),
        orient: _cell(row, 5),
        obedience: _cell(row, 6),
        email: _cell(row, 7),
        phone: _cell(row, 8),
        preferredContact: _cell(row, 9),
        protocolRank: _tryParseInt(_cell(row, 10)),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}
