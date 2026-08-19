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
];

const List<String> kVisitorHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
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
    ],
];

List<List<String>> _visitorRows(List<Visitor> visitors) => [
  kVisitorHeaders,
  for (final v in visitors)
    [
      v.civilite,
      v.firstName,
      v.lastName,
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
    required this.existing,
    required this.action,
  });

  /// Fiche telle qu'elle sera écrite, selon [action] — `null` si `skip`.
  Member? resolve(String Function() newId) {
    switch (action) {
      case ImportAction.skip:
        return null;
      case ImportAction.create:
        return Member(
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
      case ImportAction.update:
        final base = existing;
        if (base == null) return null;
        return base.copyWith(
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
    }
  }
}

class VisitorImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
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

class DirectoryImportPreview {
  final List<MemberImportRow> members;
  final List<VisitorImportRow> visitors;
  final List<DignitaryImportRow> dignitaries;
  const DirectoryImportPreview({
    required this.members,
    required this.visitors,
    required this.dignitaries,
  });
}

int? _tryParseInt(String v) => v.trim().isEmpty ? null : int.tryParse(v.trim());

/// Analyse un classeur importé : associe chaque ligne à une fiche existante
/// (nom + prénom) si elle en trouve une, avec une action par défaut
/// (mise à jour pour un doublon détecté, création sinon) — modifiable
/// ensuite ligne par ligne dans l'écran de prévisualisation. Les lignes sans
/// prénom ni nom sont ignorées (lignes vides en fin de tableau).
DirectoryImportPreview parseDirectoryWorkbook(
  List<int> bytes, {
  required List<Member> existingMembers,
  required List<Visitor> existingVisitors,
  required List<Dignitary> existingDignitaries,
}) {
  final sheets = readXlsx(bytes, [
    kSheetMembers,
    kSheetVisitors,
    kSheetDignitaries,
  ]);

  final membersByKey = {
    for (final m in existingMembers) nameKey(m.firstName, m.lastName): m,
  };
  final visitorsByKey = {
    for (final v in existingVisitors) nameKey(v.firstName, v.lastName): v,
  };
  final dignitariesByKey = {
    for (final d in existingDignitaries) nameKey(d.firstName, d.lastName): d,
  };

  final memberRows = <MemberImportRow>[];
  for (final row in (sheets[kSheetMembers] ?? const []).skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = membersByKey[nameKey(firstName, lastName)];
    memberRows.add(
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
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }

  final visitorRows = <VisitorImportRow>[];
  for (final row in (sheets[kSheetVisitors] ?? const []).skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = visitorsByKey[nameKey(firstName, lastName)];
    visitorRows.add(
      VisitorImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        function: _cell(row, 3),
        lodge: _cell(row, 4),
        orient: _cell(row, 5),
        obedience: _cell(row, 6),
        email: _cell(row, 7),
        phone: _cell(row, 8),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }

  final dignitaryRows = <DignitaryImportRow>[];
  for (final row in (sheets[kSheetDignitaries] ?? const []).skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = dignitariesByKey[nameKey(firstName, lastName)];
    dignitaryRows.add(
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

  return DirectoryImportPreview(
    members: memberRows,
    visitors: visitorRows,
    dignitaries: dignitaryRows,
  );
}
