plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.ac.trigunadharma.mobile_resource_management"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Diperlukan oleh flutter_local_notifications: plugin memakai API Java 8+
        // (java.time) yang harus di-desugar agar berjalan di Android lama.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "id.ac.trigunadharma.mobile_resource_management"
        // minSdk 24 (Android 7.0) — batas bawah yang didukung
        // flutter_local_notifications sekaligus cakupan perangkat yang wajar
        // untuk lingkungan kampus.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Tambahkan signing config rilis sebelum dipublikasikan.
            // Untuk sementara memakai debug key agar `flutter run --release`
            // tetap bisa dijalankan.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
