plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.klass.klass_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.klass.klass_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ─── Build Flavors ─────────────────────────────────────────
    //
    // Two flavors let you install dev & prod side-by-side on the
    // same device.  Each flavor picks up its own label via standard
    // Android resource overlay (src/<flavor>/res/values/strings.xml).
    //
    // Build commands:
    //   flutter run --flavor dev -t lib/main.dart
    //   flutter build apk --flavor prod  --dart-define=IS_PROD=true
    //   flutter build appbundle --flavor prod --dart-define=IS_PROD=true
    //
    flavorDimensions += listOf("environment")
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "Klass Dev"
            versionNameSuffix = "-dev"
        }
        create("prod") {
            dimension = "environment"
            applicationIdSuffix = null
            manifestPlaceholders["appName"] = "Klass"
            versionNameSuffix = null
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}