import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Datos de la llave de publicación (android/key.properties). Ese archivo y la
// llave .jks NO se suben a GitHub (están en .gitignore): si se pierden, no se
// pueden publicar actualizaciones. Guárdalos también en un lugar seguro.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mferman.wordsandmonsters"
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necesario para las notificaciones programadas
        // (flutter_local_notifications usa fechas de Java 8+).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador PERMANENTE en Google Play: no cambiarlo nunca.
        applicationId = "com.mferman.wordsandmonsters"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Google Play exige apuntar a Android 15 (API 35) o superior para
        // publicar; se fija en 36 (Android 16) para no depender de la
        // versión de Flutter instalada.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["ADMOB_APP_ID"] = providers.gradleProperty("ADMOB_APP_ID")
            .getOrElse("ca-app-pub-3940256099942544~3347511713")
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
            // Con key.properties se firma con la llave de publicación (para
            // Google Play). Sin él, con la de pruebas, para que
            // `flutter run --release` siga funcionando en tu PC.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Aviso visible en la consola: un .aab firmado con la llave de
                // pruebas lo RECHAZA Google Play al subirlo.
                logger.warn(
                    "AVISO: no existe android/key.properties. La versión release se " +
                        "firma con la llave de PRUEBAS y Google Play no la aceptará. " +
                        "Ver docs/PUBLICAR_GOOGLE_PLAY.md, paso 2."
                )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
