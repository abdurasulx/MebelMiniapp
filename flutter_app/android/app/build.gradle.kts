import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Push (FCM) — google-services.json shu joyda (android/app/) turishi kerak.
    id("com.google.gms.google-services")
}

// Play Store'ga chiqariladigan build ("release") HAQIQIY kalit bilan
// imzolanishi shart — debug kalit bilan yaratilgan .aab Play Console'ga
// yuklanadi, lekin keyingi yangilanishlar butunlay boshqa (yangi debug)
// kalit bilan chiqib qolishi va reject bo'lishi mumkin, shuning uchun
// PUL emas, ISHONCH masalasi: shu kalit birinchi chiqarishdan boshlab
// doim BIR XIL saqlanishi kerak (yo'qolsa — ilovani boshqa hech qachon
// yangilab bo'lmaydi, faqat yangi package nomi bilan qayta e'lon qilish
// qoladi). To'liq yo'riqnoma: android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "uz.vida.burchaksoft"
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
        // DIQQAT: Play Store'da e'lon qilingandan keyin bu bir marta
        // tanlanadi va keyin UMUMAN o'zgartirib bo'lmaydi (yangi ID —
        // yangi, boshqa ilova sifatida qaraladi, eski o'rnatishlar
        // yangilanmaydi). Chiqarishdan oldin oxirgi marta tasdiqlang.
        applicationId = "uz.vida.burchaksoft"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // `android/key.properties` mavjud bo'lsa (qarang
            // key.properties.example) — haqiqiy kalit bilan imzolanadi;
            // bo'lmasa (masalan oddiy lokal sinov uchun) debug kalitga
            // tushadi, shunda `flutter run --release` baribir ishlayveradi,
            // lekin BUNDAY .aab Play Console'ga yuklanmaydi.
            signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
