// Export / import groupé des répertoires Membres, Visiteurs, Dignitaires
// d'un corps de Hauts Grades — même principe que directory_xlsx_service.dart
// (loges bleues), mais un schéma différent : pas de colonnes propres à une
// loge bleue (matricule, parrain, cotisations, dates...), à la place
// Obédience / Orient / Degré, puisqu'un membre de Hauts Grades peut venir de
// n'importe quelle loge, de n'importe quelle obédience, à un degré qui n'a
// rien à voir avec le grade symbolique de sa loge bleue d'origine (voir
// Member.hautsGradesDegree, Member.obedience, Member.orient).
import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import 'directory_xlsx_service.dart'
    show
        ImportAction,
        kSheetMembers,
        kSheetVisitors,
        kSheetDignitaries,
        nameKey;
import 'xlsx_codec.dart';

const List<String> kHgMemberHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
  'Office',
  'Email',
  'Téléphone',
  'Obédience',
  'Loge mère',
  'Orient',
  'Degré',
];

const List<String> kHgVisitorHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
  'Fonction',
  "Loge d'origine",
  'Orient',
  'Obédience',
  'Email',
  'Téléphone',
  'Degré',
];

const List<String> kHgDignitaryHeaders = [
  'Civilité',
  'Prénom',
  'Nom',
  'Titre / qualité',
  "Loge d'origine",
  'Orient',
  'Obédience',
  'Email',
  'Téléphone',
  'Degré',
];

String _cell(List<String> row, int i) => i < row.length ? row[i].trim() : '';

// ─── Export ───────────────────────────────────────────────────────────

List<List<String>> _hgMemberRows(List<Member> members) => [
  kHgMemberHeaders,
  for (final m in members)
    [
      m.civilite,
      m.firstName,
      m.lastName,
      m.function,
      m.email,
      m.phone,
      m.obedience,
      m.motherLodge,
      m.orient,
      m.hautsGradesDegree,
    ],
];

List<List<String>> _hgVisitorRows(List<Visitor> visitors) => [
  kHgVisitorHeaders,
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
      v.grade,
    ],
];

List<List<String>> _hgDignitaryRows(List<Dignitary> dignitaries) => [
  kHgDignitaryHeaders,
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
      d.grade,
    ],
];

/// Classeur complet (données réelles) des trois répertoires d'un corps de
/// Hauts Grades.
List<int> buildHgDirectoryWorkbook({
  required List<Member> members,
  required List<Visitor> visitors,
  required List<Dignitary> dignitaries,
}) {
  return buildXlsx({
    kSheetMembers: _hgMemberRows(members),
    kSheetVisitors: _hgVisitorRows(visitors),
    kSheetDignitaries: _hgDignitaryRows(dignitaries),
  });
}

/// Classeur modèle : uniquement les en-têtes, aucune ligne de donnée.
List<int> buildHgDirectoryTemplate() {
  return buildXlsx({
    kSheetMembers: [kHgMemberHeaders],
    kSheetVisitors: [kHgVisitorHeaders],
    kSheetDignitaries: [kHgDignitaryHeaders],
  });
}

// ─── Import ───────────────────────────────────────────────────────────

class HgMemberImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
  final String function;
  final String email;
  final String phone;
  final String obedience;
  final String motherLodge;
  final String orient;
  final String degree;
  final Member? existing;
  ImportAction action;

  HgMemberImportRow({
    required this.civilite,
    required this.firstName,
    required this.lastName,
    required this.function,
    required this.email,
    required this.phone,
    required this.obedience,
    required this.motherLodge,
    required this.orient,
    required this.degree,
    required this.existing,
    required this.action,
  });

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
          function: function.isEmpty ? 'Aucun' : function,
          email: email,
          phone: phone,
          obedience: obedience,
          motherLodge: motherLodge,
          orient: orient,
          hautsGradesDegree: degree,
        );
      case ImportAction.update:
        final base = existing;
        if (base == null) return null;
        return base.copyWith(
          civilite: civilite,
          firstName: firstName,
          lastName: lastName,
          function: function.isEmpty ? null : function,
          email: email,
          phone: phone,
          obedience: obedience,
          motherLodge: motherLodge,
          orient: orient,
          hautsGradesDegree: degree,
        );
    }
  }
}

class HgVisitorImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
  final String function;
  final String lodge;
  final String orient;
  final String obedience;
  final String email;
  final String phone;
  final String degree;
  final Visitor? existing;
  ImportAction action;

  HgVisitorImportRow({
    required this.civilite,
    required this.firstName,
    required this.lastName,
    required this.function,
    required this.lodge,
    required this.orient,
    required this.obedience,
    required this.email,
    required this.phone,
    required this.degree,
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
          grade: degree,
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
          grade: degree,
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

class HgDignitaryImportRow {
  final String civilite;
  final String firstName;
  final String lastName;
  final String title;
  final String lodge;
  final String orient;
  final String obedience;
  final String email;
  final String phone;
  final String degree;
  final Dignitary? existing;
  ImportAction action;

  HgDignitaryImportRow({
    required this.civilite,
    required this.firstName,
    required this.lastName,
    required this.title,
    required this.lodge,
    required this.orient,
    required this.obedience,
    required this.email,
    required this.phone,
    required this.degree,
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
          grade: degree,
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
          grade: degree,
        );
    }
  }
}

/// Lignes de la feuille « Membres » d'un classeur HG importé, associées à
/// une fiche existante (nom + prénom) si elle en trouve une — voir
/// directory_xlsx_service.dart:parseMemberSheet pour le principe général.
List<HgMemberImportRow> parseHgMemberSheet(
  List<int> bytes,
  List<Member> existingMembers,
) {
  final rows = readXlsx(bytes, [kSheetMembers])[kSheetMembers] ?? const [];
  final byKey = {
    for (final m in existingMembers) nameKey(m.firstName, m.lastName): m,
  };
  final result = <HgMemberImportRow>[];
  for (final row in rows.skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = byKey[nameKey(firstName, lastName)];
    result.add(
      HgMemberImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        function: _cell(row, 3),
        email: _cell(row, 4),
        phone: _cell(row, 5),
        obedience: _cell(row, 6),
        motherLodge: _cell(row, 7),
        orient: _cell(row, 8),
        degree: _cell(row, 9),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}

List<HgVisitorImportRow> parseHgVisitorSheet(
  List<int> bytes,
  List<Visitor> existingVisitors,
) {
  final rows = readXlsx(bytes, [kSheetVisitors])[kSheetVisitors] ?? const [];
  final byKey = {
    for (final v in existingVisitors) nameKey(v.firstName, v.lastName): v,
  };
  final result = <HgVisitorImportRow>[];
  for (final row in rows.skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = byKey[nameKey(firstName, lastName)];
    result.add(
      HgVisitorImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        function: _cell(row, 3),
        lodge: _cell(row, 4),
        orient: _cell(row, 5),
        obedience: _cell(row, 6),
        email: _cell(row, 7),
        phone: _cell(row, 8),
        degree: _cell(row, 9),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}

List<HgDignitaryImportRow> parseHgDignitarySheet(
  List<int> bytes,
  List<Dignitary> existingDignitaries,
) {
  final rows =
      readXlsx(bytes, [kSheetDignitaries])[kSheetDignitaries] ?? const [];
  final byKey = {
    for (final d in existingDignitaries) nameKey(d.firstName, d.lastName): d,
  };
  final result = <HgDignitaryImportRow>[];
  for (final row in rows.skip(1)) {
    final firstName = _cell(row, 1);
    final lastName = _cell(row, 2);
    if (firstName.isEmpty && lastName.isEmpty) continue;
    final existing = byKey[nameKey(firstName, lastName)];
    result.add(
      HgDignitaryImportRow(
        civilite: _cell(row, 0),
        firstName: firstName,
        lastName: lastName,
        title: _cell(row, 3),
        lodge: _cell(row, 4),
        orient: _cell(row, 5),
        obedience: _cell(row, 6),
        email: _cell(row, 7),
        phone: _cell(row, 8),
        degree: _cell(row, 9),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}
