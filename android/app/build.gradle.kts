import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de signature release stable (voir android/key.properties, jamais
// commitée) : condition d'une mise à jour installable par-dessus une
// version déjà en place, sans désinstallation. Absente sur un poste qui
// n'a pas besoin de builder de release (CI de simple vérification, poste
// d'un contributeur) : on retombe alors sur la signature debug.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "re.benou.benou_re"
    // flutter_plugin_android_lifecycle (dépendance transitive de file_picker)
    // exige compileSdk >= 36 : flutter.compileSdkVersion (fourni par le SDK
    // Flutter installé) reste en 34, d'où ce forçage explicite.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Une loge = un flavor. Chaque flavor porte ce qui doit être figé dans le
    // binaire : l'identifiant d'application (auquel sont rattachés le client
    // OAuth Google et la fiche Play Store) et le nom affiché sous l'icône.
    // Le reste de l'identité (nom, orient, dossiers Drive) est relu depuis
    // Firestore, cf. lib/config/lodge_config.dart.
    //
    // Pour ajouter une loge : créer un flavor ci-dessous, puis dans
    // `android/app/src/<flavor>/` déposer le `google-services.json` de son
    // projet Firebase et un `res/values/strings.xml` définissant `app_name`.
    // Builder ensuite avec `--flavor <flavor>`.
    flavorDimensions += "loge"

    productFlavors {
        create("benoure") {
            dimension = "loge"
            // Identifiant historique, conservé tel quel : le changer romprait
            // la mise à jour des applications déjà installées et invaliderait
            // le client OAuth Android utilisé pour Google Drive.
            applicationId = "re.benou.benou_re"
        }
        create("petitprince") {
            dimension = "loge"
            applicationId = "re.gldb.petitprince"
        }
        create("templehorus") {
            dimension = "loge"
            applicationId = "re.gldb.templehorus"
        }
        create("alkhemia") {
            dimension = "loge"
            applicationId = "re.gldb.alkhemia"
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}