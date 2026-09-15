// Corps de Hauts Grades gérés depuis le flavor Grande Loge (IAH-MES,
// MAA-Kherou) — contrairement aux 4 loges bleues, ils n'ont pas leur propre
// projet Firebase : leurs données vivent dans des collections dédiées du
// projet grande-loge-bourbon (voir hg_body_service.dart et firestore.rules),
// pas dans `members`/`sessions` (déjà utilisées par les 5 comptes officiers).
import 'member.dart';

class HgBody {
  final String key;
  final String label;
  final String membersCollection;
  final String sessionsCollection;
  final String visitorsCollection;
  final String dignitariesCollection;
  const HgBody({
    required this.key,
    required this.label,
    required this.membersCollection,
    required this.sessionsCollection,
    required this.visitorsCollection,
    required this.dignitariesCollection,
  });
}

const HgBody kIahMes = HgBody(
  key: 'iahmes',
  label: 'IAH-MES',
  membersCollection: 'iahmesMembers',
  sessionsCollection: 'iahmesSessions',
  visitorsCollection: 'iahmesVisitors',
  dignitariesCollection: 'iahmesDignitaries',
);

const HgBody kMaaKherou = HgBody(
  key: 'maakherou',
  label: 'MAA-Kherou',
  membersCollection: 'maakherouMembers',
  sessionsCollection: 'maakherouSessions',
  visitorsCollection: 'maakherouVisitors',
  dignitariesCollection: 'maakherouDignitaries',
);

/// Droit d'édition (membres, tenues...) d'un corps de Hauts Grades — décidé
/// par rôle (voir Member.role), explicitement différent par corps :
/// IAH-MES : Sérénissime + titulaire du compte IAH-MES (role atelier_4_14),
/// pas le Grand Maître. MAA-Kherou : Sérénissime + Grand Maître + titulaire
/// du compte MAA-Kherou (role perfection). L'administrateur peut toujours.
bool canEditHgBody(Member? user, HgBody body) {
  if (user == null) return false;
  if (user.isAdmin) return true;
  if (body.key == kIahMes.key) {
    return user.role == 'sgm' || user.role == 'atelier_4_14';
  }
  if (body.key == kMaaKherou.key) {
    return user.role == 'sgm' || user.role == 'gm' || user.role == 'perfection';
  }
  return false;
}
