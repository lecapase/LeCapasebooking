plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    // The Flutter Gradle Plugin must be applied
    // after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.lecapase_booking"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // =========================================================
    // JAVA 17 + CORE LIBRARY DESUGARING
    // =========================================================

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true
    }

    // =========================================================
    // CONFIGURAZIONE APP
    // =========================================================

    defaultConfig {
        applicationId = "com.example.lecapase_booking"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // =========================================================
    // BUILD TYPES
    // =========================================================

    buildTypes {
        release {
            // Per ora utilizziamo la chiave debug.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// =============================================================
// KOTLIN
// =============================================================

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// =============================================================
// DIPENDENZE ANDROID
// =============================================================

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}

// =============================================================
// FLUTTER
// =============================================================

flutter {
    source = "../.."
}