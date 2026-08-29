// Correspondance dossier Drive ↔ fonctions autorisées, pour la
// synchronisation automatique des accès (voir drive_access_sync_service.dart).
// Configurée par Loge dans `config/settings.driveAccessFolders`, un peu
// comme `libraryFolders` l'est par grade.
const String kRoleVenerable = 'venerable';
const String kRoleSecretaire = 'secretaire';
const String kRoleTresorier = 'tresorier';

class DriveAccessFolder {
  final String name;
  final String folderId;
  final List<String> roles;

  const DriveAccessFolder({
    required this.name,
    required this.folderId,
    required this.roles,
  });

  factory DriveAccessFolder.fromMap(Map<String, dynamic> map) {
    return DriveAccessFolder(
      name: (map['name'] ?? '') as String,
      folderId: (map['folderId'] ?? '') as String,
      roles: List<String>.from(map['roles'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'folderId': folderId,
        'roles': roles,
      };
}
