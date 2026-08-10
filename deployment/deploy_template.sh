echo "Opérations principales commentées — exécutez manuellement les étapes sensibles."
echo "Après création, téléchargez 'google-services.json' et 'GoogleService-Info.plist' depuis Firebase Console."
echo "Exécutez ensuite: flutterfire configure --project=${PROJECT_ID}"
#!/usr/bin/env bash
# Script d'automatisation pour création/configuration minimale d'un projet
# Firebase pour une loge. Supporte --dry-run et --yes pour confirmer automatiquement.

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <PROJECT_ID> <LOGE_SLUG> [--dry-run] [--yes]"
  echo "Ex: $0 benou-re-le-petit-prince-prod le-petit-prince --dry-run"
  exit 1
fi

PROJECT_ID="$1"
LOGE_SLUG="$2"
shift 2

DRY_RUN=false
YES=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --yes) YES=true ;;
    *) echo "Option inconnue: $arg" ; exit 1 ;;
  esac
done

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "$1 introuvable"; return 1; }
}

check_cmd gcloud || exit 1
check_cmd firebase || { echo "firebase CLI introuvable — installez 'npm i -g firebase-tools'"; exit 1; }
check_cmd flutterfire || { echo "flutterfire introuvable — installez 'dart pub global activate flutterfire_cli'"; exit 1; }

echo "Projet=${PROJECT_ID}  loge=${LOGE_SLUG}  dry-run=${DRY_RUN}"

if [ "$YES" = false ]; then
  read -p "Confirmer exécution (oui/non) ? " answer
  if [ "$answer" != "oui" ]; then echo "Annulation."; exit 0; fi
fi

DRY_PREFIX="RUN:"
if [ "$DRY_RUN" = true ]; then DRY_PREFIX="DRY-RUN:"; fi

exec_cmd() {
  echo "$DRY_PREFIX $1"
  if [ "$DRY_RUN" = false ]; then eval "$1"; fi
}

supported_sdkconfig() {
  if [ "$DRY_RUN" = true ]; then return 0; fi
  if firebase apps:sdkconfig --help >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

get_app_id() {
  echo "$1" | python -c 'import sys, json; print(json.load(sys.stdin).get("appId", ""))'
}

# 1) Créer le projet GCP
exec_cmd "gcloud projects create ${PROJECT_ID} --name=\"Bénou-Re - ${LOGE_SLUG}\""

# 2) Activer APIs
exec_cmd "gcloud services enable firestore.googleapis.com storage.googleapis.com --project=${PROJECT_ID}"

# 3) Créer projet Firebase
exec_cmd "firebase projects:create ${PROJECT_ID} --display-name \"Bénou-Re - ${LOGE_SLUG}\""

# 4) Créer compte de service
exec_cmd "gcloud iam service-accounts create deployer --display-name 'Deployer' --project ${PROJECT_ID}"
exec_cmd "gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=\"serviceAccount:deployer@${PROJECT_ID}.iam.gserviceaccount.com\" --role=\"roles/firebase.admin\""

# 5) Créer apps (Android/iOS)
CLEAN_SLUG="$(echo "$LOGE_SLUG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g')"
ANDROID_PKG="com.benoure.${CLEAN_SLUG}.android"
IOS_BUNDLE="com.benoure.${CLEAN_SLUG}.ios"

if [ "$DRY_RUN" = true ]; then
  exec_cmd "firebase apps:create android ${ANDROID_PKG} --project=${PROJECT_ID} --json"
  exec_cmd "firebase apps:create ios ${IOS_BUNDLE} --project=${PROJECT_ID} --json"
  echo "DRY-RUN: tentative de téléchargement automatique des fichiers de config si la CLI le permet."
else
  ANDROID_JSON=$(firebase apps:create android ${ANDROID_PKG} --project=${PROJECT_ID} --json)
  IOS_JSON=$(firebase apps:create ios ${IOS_BUNDLE} --project=${PROJECT_ID} --json)
  ANDROID_APP_ID=$(get_app_id "$ANDROID_JSON")
  IOS_APP_ID=$(get_app_id "$IOS_JSON")

  if supported_sdkconfig; then
    if [ -n "$ANDROID_APP_ID" ]; then
      exec_cmd "firebase apps:sdkconfig android ${ANDROID_APP_ID} --out=android/app/google-services.json --project=${PROJECT_ID}"
    fi
    if [ -n "$IOS_APP_ID" ]; then
      exec_cmd "firebase apps:sdkconfig ios ${IOS_APP_ID} --out=ios/Runner/GoogleService-Info.plist --project=${PROJECT_ID}"
    fi
  else
    echo "La CLI Firebase ne semble pas supporter 'apps:sdkconfig'. Téléchargement manuel recommandé."
  fi
fi

# 6) Générer lib/firebase_options.dart via FlutterFire
exec_cmd "flutterfire configure --project=${PROJECT_ID} --out=lib/firebase_options.dart"

echo "Opérations terminées. Vérifiez la console Firebase pour télécharger les fichiers de configuration si nécessaire."

exit 0
