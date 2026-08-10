# Guide d'automatisation — Exécution des scripts

Ce guide explique comment utiliser les scripts d'automatisation fournis dans
`deployment/` pour créer un projet Firebase pour une loge.

Fichiers
- `deploy_template.ps1` — script PowerShell (Windows)
- `deploy_template.sh` — script Bash (Linux/macOS/WSL)
- `README_FULL.md` — procédure complète et checklist

Pré-requis
- Authentification: `gcloud auth login` puis `firebase login`
- Outils installés: `gcloud`, `firebase` CLI, `dart` (pour `flutterfire`)

Exemples d'exécution

PowerShell (dry-run):

```powershell
.\deployment\deploy_template.ps1 -ProjectId "benou-re-le-petit-prince-prod" -LogeName "Le Petit Prince" -DryRun
```

PowerShell (exécution, demande confirmation):

```powershell
.\deployment\deploy_template.ps1 -ProjectId "benou-re-le-petit-prince-prod" -LogeName "Le Petit Prince"
```

Bash (dry-run):

```bash
./deployment/deploy_template.sh benou-re-le-petit-prince-prod le-petit-prince --dry-run
```

Bash (exécution non-interactive):

```bash
./deployment/deploy_template.sh benou-re-le-petit-prince-prod le-petit-prince --yes
```

Notes importantes
- Les scripts peuvent créer des ressources facturées. Vérifiez le compte de
  facturation lié au `PROJECT_ID`.
- Les fichiers `google-services.json` et `GoogleService-Info.plist` doivent
  généralement être téléchargés depuis la Console Firebase (l'interface web) et
  placés respectivement dans `android/app/` et `ios/Runner/`.
- Après création, exécuter `flutterfire configure --project=<PROJECT_ID>` pour
  générer `lib/firebase_options.dart`.

Besoin d'aide
- Si vous voulez, je peux préparer une version du script qui télécharge
  automatiquement les fichiers de config quand la CLI le permet, ou générer
  directement un zip contenant les artifacts prêts à déployer.
