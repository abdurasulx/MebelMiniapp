plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Push (FCM) — google-services.json shu joyda (android/app/) turishi kerak.
    id("com.google.gms.google-services")
}

android {
    namespace = "uz.furnitureplatform.furniture_platform_mobile"
    // Flutter'ning o'zi bergan standart qiymat (`flutter.compileSdkVersion`)
    // o'rnatilgan Flutter SDK versiyasiga qarab har xil kompyuterda har xil
    // bo'lib qolishi mumkin — masalan eski Flutter SDK'da 33 bo'lib,
    // `share_plus` kabi plaginlar (androidx.core 1.13.1 va h.k. orqali)
    // kamida 34 talab qilgani sabab build "AAR metadata" xatosi bilan
    // yiqilib qolgan. Shu sabab bu yerda qat'iy belgilangan — har qanday
    // mashinada, Flutter SDK versiyasidan qat'i nazar, bir xil natija.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (push uchun) buni talab qiladi.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "uz.furnitureplatform.furniture_platform_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
