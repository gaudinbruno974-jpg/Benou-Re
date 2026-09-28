// Calcule et applique la « MAJ des Membres » (bouton de l'écran Loges
// Bleues, Grande Loge) : ajoute dans chaque loge les Visiteurs/Dignitaires
// qui manquent (présents dans au moins une des 3 autres loges, absents
// d'elle, et dont la loge d'origine n'est pas la sienne — voir la
// synchronisation faite à la main le 2026-09-28), et corrige le
// téléphone/prénom/nom des fiches Membres/Visiteurs/Dignitaires qui ne
// suivent pas les conventions (voir directory_xlsx_service.dart pour la
// détection/normalisation, réutilisée telle quelle). N'écrit jamais un
// autre champ, ne crée ni ne supprime jamais un Membre — voir
// firestore.rules (isGrandeLogeSync) pour la limite appliquée côté serveur.
import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import 'directory_xlsx_service.dart';
import 'lodge_reader_service.dart';

/// Une correction de téléphone/prénom/nom sur une fiche déjà existante.
class ContactFix {
  final LodgeReaderTarget target;
  final String collection; // 'members' | 'visitors' | 'dignitaries'
  final String docId;
  final String personLabel;
  final String field; // 'phone' | 'firstName' | 'lastName'
  final String oldValue;
  final String newValue;
  const ContactFix({
    required this.target,
    required this.collection,
    required this.docId,
    required this.personLabel,
    required this.field,
    required this.oldValue,
    required this.newValue,
  });
}

class DirectorySyncPlan {
  final Map<String, List<Visitor>> visitorsToCreate;
  final Map<String, List<Dignitary>> dignitariesToCreate;
  final List<ContactFix> fixes;
  const DirectorySyncPlan({
    required this.visitorsToCreate,
    required this.dignitariesToCreate,
    required this.fixes,
  });

  int get creationsCount =>
      visitorsToCreate.values.fold(0, (n, l) => n + l.length) +
      dignitariesToCreate.values.fold(0, (n, l) => n + l.length);

  int get totalChanges => creationsCount + fixes.length;
}

LodgeReaderTarget? _targetForLodgeName(
  String? lodgeName,
  List<LodgeReaderTarget> targets,
) {
  final f = foldLabel(lodgeName ?? '');
  for (final t in targets) {
    if (f.contains(foldLabel(t.label))) return t;
  }
  return null;
}

Map<String, List<T>> _mergeGroups<T>(
  List<T> items,
  String Function(T) firstNameOf,
  String Function(T) lastNameOf,
) {
  final groups = <String, List<T>>{};
  for (final item in items) {
    final key = foldLabel('${firstNameOf(item)} ${lastNameOf(item)}');
    groups.putIfAbsent(key, () => []).add(item);
  }
  return groups;
}

/// Calcule le plan complet à partir des répertoires déjà lus des 4 loges
/// ([lodges], même ordre que [targets]).
DirectorySyncPlan computeDirectorySyncPlan(
  List<LodgeReaderTarget> targets,
  List<LodgeDirectory> lodges,
) {
  final visitorsToCreate = <String, List<Visitor>>{
    for (final t in targets) t.key: [],
  };
  final dignitariesToCreate = <String, List<Dignitary>>{
    for (final t in targets) t.key: [],
  };
  final fixes = <ContactFix>[];

  // ── Corrections téléphone/casse sur les fiches déjà existantes ──
  void collectContactFixes(
    LodgeReaderTarget target,
    String collection,
    String docId,
    String personLabel,
    String phone,
    String firstName,
    String lastName,
  ) {
    final newPhone = normalizePhoneNumber(phone);
    if (newPhone != phone) {
      fixes.add(
        ContactFix(
          target: target,
          collection: collection,
          docId: docId,
          personLabel: personLabel,
          field: 'phone',
          oldValue: phone,
          newValue: newPhone,
        ),
      );
    }
    final newLast = lastName.trim().isEmpty ? lastName : lastName.toUpperCase();
    if (newLast != lastName) {
      fixes.add(
        ContactFix(
          target: target,
          collection: collection,
          docId: docId,
          personLabel: personLabel,
          field: 'lastName',
          oldValue: lastName,
          newValue: newLast,
        ),
      );
    }
    final newFirst = normalizeTitleCase(firstName);
    if (newFirst != firstName) {
      fixes.add(
        ContactFix(
          target: target,
          collection: collection,
          docId: docId,
          personLabel: personLabel,
          field: 'firstName',
          oldValue: firstName,
          newValue: newFirst,
        ),
      );
    }
  }

  for (var i = 0; i < targets.length; i++) {
    final target = targets[i];
    final lodge = lodges[i];
    for (final m in lodge.members) {
      collectContactFixes(
        target,
        'members',
        m.id,
        m.fullName,
        m.phone,
        m.firstName,
        m.lastName,
      );
    }
    for (final v in lodge.visitors) {
      collectContactFixes(
        target,
        'visitors',
        v.id,
        v.fullName,
        v.phone,
        v.firstName,
        v.lastName,
      );
    }
    for (final d in lodge.dignitaries) {
      collectContactFixes(
        target,
        'dignitaries',
        d.id,
        d.fullName,
        d.phone,
        d.firstName,
        d.lastName,
      );
    }
  }

  // ── Visiteurs manquants (liste commune des 4 loges, moins ceux dont la
  // loge d'origine est la loge elle-même) ──
  final allVisitors = <Visitor>[for (final l in lodges) ...l.visitors];
  final visitorGroups = _mergeGroups(
    allVisitors,
    (v) => v.firstName,
    (v) => v.lastName,
  );
  final presentVisitorsByKey = <String, Set<String>>{};
  for (var i = 0; i < targets.length; i++) {
    for (final v in lodges[i].visitors) {
      final key = foldLabel('${v.firstName} ${v.lastName}');
      presentVisitorsByKey.putIfAbsent(key, () => {}).add(targets[i].key);
    }
  }
  visitorGroups.forEach((key, group) {
    // La fiche la plus complète sert de base pour la fiche à créer.
    final base =
        (List<Visitor>.from(group)..sort(
              (a, b) => _completeness(
                _visitorFields(b),
              ).compareTo(_completeness(_visitorFields(a))),
            ))
            .first;
    final home = _targetForLodgeName(base.lodge, targets);
    final present = presentVisitorsByKey[key] ?? {};
    for (final target in targets) {
      if (home != null && home.key == target.key) continue;
      if (present.contains(target.key)) continue;
      visitorsToCreate[target.key]!.add(
        Visitor(
          id: '',
          civilite: base.civilite,
          firstName: base.firstName,
          lastName: base.lastName,
          grade: base.grade,
          function: base.function,
          lodge: base.lodge,
          orient: base.orient,
          obedience: base.obedience,
          email: base.email,
          phone: base.phone,
        ),
      );
    }
  });

  // ── Dignitaires manquants (même principe) ──
  final allDignitaries = <Dignitary>[for (final l in lodges) ...l.dignitaries];
  final dignitaryGroups = _mergeGroups(
    allDignitaries,
    (d) => d.firstName,
    (d) => d.lastName,
  );
  final presentDignitariesByKey = <String, Set<String>>{};
  for (var i = 0; i < targets.length; i++) {
    for (final d in lodges[i].dignitaries) {
      final key = foldLabel('${d.firstName} ${d.lastName}');
      presentDignitariesByKey.putIfAbsent(key, () => {}).add(targets[i].key);
    }
  }
  dignitaryGroups.forEach((key, group) {
    final base =
        (List<Dignitary>.from(group)..sort(
              (a, b) => _completeness(
                _dignitaryFields(b),
              ).compareTo(_completeness(_dignitaryFields(a))),
            ))
            .first;
    final home = _targetForLodgeName(base.lodge, targets);
    final present = presentDignitariesByKey[key] ?? {};
    for (final target in targets) {
      if (home != null && home.key == target.key) continue;
      if (present.contains(target.key)) continue;
      dignitariesToCreate[target.key]!.add(
        Dignitary(
          id: '',
          civilite: base.civilite,
          firstName: base.firstName,
          lastName: base.lastName,
          title: base.title,
          lodge: base.lodge,
          orient: base.orient,
          obedience: base.obedience,
          email: base.email,
          phone: base.phone,
          preferredContact: base.preferredContact,
          protocolRank: base.protocolRank,
        ),
      );
    }
  });

  return DirectorySyncPlan(
    visitorsToCreate: visitorsToCreate,
    dignitariesToCreate: dignitariesToCreate,
    fixes: fixes,
  );
}

List<String> _visitorFields(Visitor v) => [
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
];

List<String> _dignitaryFields(Dignitary d) => [
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
];

int _completeness(List<String> fields) =>
    fields.where((f) => f.trim().isNotEmpty).length;

/// Écrit le plan dans les 4 bases (créations puis corrections), avec le
/// compte technique lecture-grandeloge. `onProgress` reçoit le nombre
/// d'opérations effectuées au fur et à mesure.
Future<void> applyDirectorySyncPlan(
  DirectorySyncPlan plan, {
  void Function(int done, int total)? onProgress,
}) async {
  final reader = LodgeReaderService.instance;
  var done = 0;
  final total = plan.totalChanges;
  void tick() {
    done++;
    onProgress?.call(done, total);
  }

  for (final entry in plan.visitorsToCreate.entries) {
    final target = kLodgeReaderTargets.firstWhere((t) => t.key == entry.key);
    for (final v in entry.value) {
      await reader.createVisitor(target, v);
      tick();
    }
  }
  for (final entry in plan.dignitariesToCreate.entries) {
    final target = kLodgeReaderTargets.firstWhere((t) => t.key == entry.key);
    for (final d in entry.value) {
      await reader.createDignitary(target, d);
      tick();
    }
  }
  for (final fix in plan.fixes) {
    switch (fix.collection) {
      case 'members':
        await reader.updateMemberContact(
          fix.target,
          fix.docId,
          phone: fix.field == 'phone' ? fix.newValue : null,
          firstName: fix.field == 'firstName' ? fix.newValue : null,
          lastName: fix.field == 'lastName' ? fix.newValue : null,
        );
      case 'visitors':
        await reader.updateVisitorContact(
          fix.target,
          fix.docId,
          phone: fix.field == 'phone' ? fix.newValue : null,
          firstName: fix.field == 'firstName' ? fix.newValue : null,
          lastName: fix.field == 'lastName' ? fix.newValue : null,
        );
      case 'dignitaries':
        await reader.updateDignitaryContact(
          fix.target,
          fix.docId,
          phone: fix.field == 'phone' ? fix.newValue : null,
          firstName: fix.field == 'firstName' ? fix.newValue : null,
          lastName: fix.field == 'lastName' ? fix.newValue : null,
        );
    }
    tick();
  }
}
