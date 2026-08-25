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
String _formatNum(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

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
