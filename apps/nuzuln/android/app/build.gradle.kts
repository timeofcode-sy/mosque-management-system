import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The permanent release key (keystore + key.properties) lives outside the repository, by default
// in ~/.nuzuln-signing/ or wherever NUZULN_SIGNING_PROPERTIES points. Without it a release build is
// signed with the debug key, which cannot update an installed app: scripts/export-apps.ps1 refuses
// to export Android apps then. See docs/APP-UPDATES.md (signing key).
val signingProperties = file(
    System.getenv("NUZULN_SIGNING_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.nuzuln-signing/key.properties",
)
val releaseSigning = Properties().apply {
    if (signingProperties.exists()) signingProperties.inputStream().use { load(it) }
}

android {
    namespace = "com.timeofcode.nuzuln"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Owner (timeofcode) then app (nuzuln). Fixed once the app ships to the store.
        // One app for teacher, guardian and student; the account's role picks the screens.
        applicationId = "com.timeofcode.nuzuln"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Native libraries compressed inside the APK: stored, they made two thirds of a 66-75 MB file;
    // compressed the download halves, and Android unpacks them once at install
    // (docs/suggestions/SUGGESTIONS.md, 1.2 #1).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        if (signingProperties.exists()) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingProperties.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("Nuzuln: no release key at $signingProperties - signing with the debug key.")
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

// Push notifications need google-services.json registered in Firebase under
// com.timeofcode.nuzuln. Until it is added the app builds and runs without them: the
// Dart side swallows a failed Firebase init (lib/main.dart).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
