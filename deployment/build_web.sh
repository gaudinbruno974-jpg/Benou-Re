#!/usr/bin/env bash
# Build le site web d'une loge : flutter ne fusionne pas de dossiers "flavor"
# pour le web (contrairement à Android/src/<flavor>), donc ce script copie
# temporairement web-flavors/<flavor>/ par-dessus web/ avant le build, puis
# restaure web/ (état "benoure", celui versionné) juste après.
#
# Usage : ./deployment/build_web.sh benoure
#         ./deployment/build_web.sh petitprince
#         ./deployment/build_web.sh templehorus
set -euo pipefail

FLAVOR="${1:-}"
if [[ "$FLAVOR" != "benoure" && "$FLAVOR" != "petitprince" && "$FLAVOR" != "templehorus" ]]; then
  echo "Usage: $0 <benoure|petitprince|templehorus>" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

override_applied=0
cleanup() {
  if [[ "$override_applied" == "1" ]]; then
    git checkout -- web/
  fi
}
trap cleanup EXIT

if [[ "$FLAVOR" != "benoure" ]]; then
  flavor_dir="web-flavors/$FLAVOR"
  if [[ ! -d "$flavor_dir" ]]; then
    echo "Dossier $flavor_dir introuvable." >&2
    exit 1
  fi

  if [[ -n "$(git status --porcelain -- web/)" ]]; then
    echo "web/ contient des modifications non commitées. Commite ou stash-les avant de builder un autre flavor web (ce script restaure web/ via 'git checkout -- web/' en fin de build, ce qui écraserait ces changements)." >&2
    exit 1
  fi

  cp -r "$flavor_dir"/* web/
  override_applied=1
fi

# Le build web de Flutter est incrémental : en réutilisant build/ et
# .dart_tool/ d'un run précédent (autre flavor, ou web/ restauré entre deux
# builds), il a pu sauter la recopie de fichiers statiques (manifest.json,
# favicon.png, flutter_service_worker.js) en les croyant à jour. Un simple
# `rm -rf build/web` ne suffit pas (le cache incriminé vit aussi dans
# .dart_tool/) : on repart donc d'un `flutter clean` à chaque fois.
flutter clean
flutter pub get

flutter build web --release "--dart-define=FLAVOR=$FLAVOR"

echo "Build web '$FLAVOR' prêt dans build/web/."
if [[ "$FLAVOR" == "benoure" ]]; then
  echo "Déploiement : firebase deploy --only hosting"
else
  echo "Déploiement : firebase deploy --only hosting -P $FLAVOR"
fi
