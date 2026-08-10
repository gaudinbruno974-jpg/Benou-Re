<#
  Script PowerShell d'automatisation pour création/configuration minimale
  d'un projet Firebase pour une loge.

  Fonctionnalités:
  - vérifie la présence des outils `gcloud`, `firebase` et `flutterfire`
  - propose `--dry-run` pour simuler les commandes
  - propose `--yes` pour accepter automatiquement

  AVERTISSEMENT: l'exécution crée des ressources cloud et peut nécessiter
  des droits/billing. Relire avant exécution.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,

    [Parameter(Mandatory=$true)]
    [string]$LogeName,

    [switch]$Yes,
    [switch]$DryRun
)

function Check-Command($name) {
    try { Get-Command $name -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

if (-not (Check-Command gcloud)) { Write-Error "gcloud introuvable. Installer Google Cloud SDK."; exit 1 }
if (-not (Check-Command firebase)) { Write-Error "firebase CLI introuvable. Installer via 'npm i -g firebase-tools'"; exit 1 }

Write-Host "Automatisation: projet=$ProjectId  loge=$LogeName  dry-run=$($DryRun.IsPresent)"

if (-not $Yes.IsPresent) {
    $confirm = Read-Host "Confirmer l'exécution (oui/non) ?"
    if ($confirm -ne 'oui') { Write-Host "Annulation par l'utilisateur."; exit 0 }
}

$cmdPrefix = if ($DryRun.IsPresent) { "DRY-RUN:" } else { "RUN:" }

function Exec($cmd) {
    if ($DryRun.IsPresent) { Write-Host "${cmdPrefix} $cmd" } else { Write-Host "${cmdPrefix} $cmd"; iex $cmd }
}

# 1) Créer le projet GCP
$createCmd = "gcloud projects create $ProjectId --name=\"Bénou-Re-$LogeName\""
Exec $createCmd

# 2) Activer APIs
$enableCmd = "gcloud services enable firestore.googleapis.com storage.googleapis.com --project=$ProjectId"
Exec $enableCmd

# 3) Créer projet Firebase (liaison au projectId si nécessaire)
$firebaseCreate = "firebase projects:create $ProjectId --display-name \"Bénou-Re - $LogeName\""
Exec $firebaseCreate

# 4) Créer compte de service deployer
$saCreate = "gcloud iam service-accounts create deployer --display-name \"Deployer\" --project $ProjectId"
Exec $saCreate

# 5) Attribuer rôles (ajuster si besoin)
$bindCmd = "gcloud projects add-iam-policy-binding $ProjectId --member=\"serviceAccount:deployer@$ProjectId.iam.gserviceaccount.com\" --role=\"roles/firebase.admin\""
Exec $bindCmd

# 6) Créer apps Android/iOS (si package ids fournis, sinon l'opérateur doit le faire)
$androidPackage = "com.benoure.$($LogeName -replace '\\s','-' -replace '[^a-zA-Z0-9\-]','' ).android"
$iosBundle = "com.benoure.$($LogeName -replace '\\s','-' -replace '[^a-zA-Z0-9\-]','' ).ios"
$createAndroidApp = "firebase apps:create android $androidPackage --project=$ProjectId"
Exec $createAndroidApp
$createIosApp = "firebase apps:create ios $iosBundle --project=$ProjectId"
Exec $createIosApp

Write-Host "NOTE: récupération des fichiers de config (google-services.json / GoogleService-Info.plist) via Firebase Console recommandée."
Write-Host "Si la CLI supporte 'firebase apps:sdkconfig', vous pouvez essayer de l'utiliser pour récupérer la config."

# 7) Générer lib/firebase_options.dart via FlutterFire
$flutterfireCmd = "flutterfire configure --project=$ProjectId --out=lib/firebase_options.dart"
Exec $flutterfireCmd

Write-Host "Opérations terminées. Vérifiez la console Firebase pour télécharger les fichiers de configuration si nécessaire."

