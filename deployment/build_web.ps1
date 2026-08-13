# Build le site web d'une loge : flutter ne fusionne pas de dossiers "flavor"
# pour le web (contrairement à Android/src/<flavor>), donc ce script copie
# temporairement web-flavors/<flavor>/ par-dessus web/ avant le build, puis
# restaure web/ (état "benoure", celui versionné) juste après.
#
# Usage : .\deployment\build_web.ps1 -Flavor benoure
#         .\deployment\build_web.ps1 -Flavor petitprince

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("benoure", "petitprince")]
    [string]$Flavor
)

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$overrideApplied = $false

try {
    if ($Flavor -ne "benoure") {
        $flavorDir = "web-flavors/$Flavor"
        if (-not (Test-Path $flavorDir)) {
            throw "Dossier $flavorDir introuvable."
        }

        $dirty = git status --porcelain -- web/
        if ($dirty) {
            throw "web/ contient des modifications non commitées. Commite ou stash-les avant de builder un autre flavor web (ce script restaure web/ via 'git checkout -- web/' en fin de build, ce qui écraserait ces changements)."
        }

        Copy-Item -Path "$flavorDir/*" -Destination "web" -Recurse -Force
        $overrideApplied = $true
    }

    # Le build web de Flutter est incrémental : en réutilisant build/ et
    # .dart_tool/ d'un run précédent (autre flavor, ou web/ restauré entre
    # deux builds), il a pu sauter la recopie de fichiers statiques
    # (manifest.json, favicon.png, flutter_service_worker.js) en les croyant
    # à jour. Un simple `rm -rf build/web` ne suffit pas à éliminer ce risque
    # (le cache incriminé vit aussi dans .dart_tool/) : on repart donc d'un
    # `flutter clean` à chaque fois pour garantir un build complet.
    & flutter clean
    if ($LASTEXITCODE -ne 0) {
        throw "flutter clean a échoué (code $LASTEXITCODE)"
    }

    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get a échoué (code $LASTEXITCODE)"
    }

    & flutter build web --release "--dart-define=FLAVOR=$Flavor"
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build web a échoué (code $LASTEXITCODE)"
    }
}
finally {
    if ($overrideApplied) {
        git checkout -- web/
    }
}

Write-Host "Build web '$Flavor' prêt dans build/web/."
if ($Flavor -eq "benoure") {
    Write-Host "Déploiement : firebase deploy --only hosting"
} else {
    Write-Host "Déploiement : firebase deploy --only hosting -P $Flavor"
}
