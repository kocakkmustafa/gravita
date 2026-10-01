@file:Suppress("DEPRECATION")

// ⚠️ `java.util.Properties` İMPORT'U ZORUNLU — ve bu ölçülmüş bir tuzaktır.
//
// Kotlin DSL'inde çıplak `java`, `JavaPluginExtension`a çözümlenir ve
// **paket adını gölgeler**. Lissom'un metin kapısı *"koruma VAR"* dedi ve
// HAKLIYDI — ama ***koruma DERLENMİYORDU.*** Bu yüzden bu dosyanın kapısı
// metinle değil GERÇEK GRADLE KOŞUMUYLA doğrulanır:
//   JAVA_HOME=…/temurin-17.jdk/… ./gradlew :app:assembleRelease --dry-run
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yulalab.gravita"
    compileSdk = 37
    buildToolsVersion = "37.0.0"
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yulalab.gravita"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ⭐ İMZA SESSİZLİĞİ KALDIRILDI (G-192, yayın denetimi kalemi ⑤a).
    //
    // Şablonun bıraktığı hâl release'i DEBUG anahtarıyla imzalıyordu ve
    // bunu SESSİZCE yapıyordu: `flutter build appbundle` başarıyla biter,
    // artefakt üretilir, ve Play onu REDDEDER. Kusur artefaktı üretmesinde
    // değil, üretirken hiçbir şey SÖYLEMEMESİNDE.
    //
    // ⛔ Keystore BURADA ÜRETİLMEZ: imza kimliği bir SIRDIR ve kurucunundur
    // (`~/.secrets/yula/`), workspace'e asla. Bu blok yalnız SESSİZLİĞİ
    // kaldırır — kalem ikiye bölünmüştür (yapılandırma+kapı hat-yereli,
    // keystore kurucu).
    //
    // İki referans birleştirildi (ikisi de ölçülmüş, icat değil):
    //   · JabLab: `key.properties` yoksa `signingConfig = null` — debug'a
    //     DÜŞMEZ — ve release görev grafiğinde `GradleException`.
    //   · Lissom: debug'a düşmek AÇIK KARAR olmalı → `-PallowDebugSigning`.
    val keyPropsFile = rootProject.file("key.properties")
    val allowDebugSigning =
        (project.findProperty("allowDebugSigning") as String?) == "true"

    signingConfigs {
        if (keyPropsFile.exists()) {
            create("release") {
                val props = Properties()
                keyPropsFile.inputStream().use { props.load(it) }
                storeFile = props.getProperty("storeFile")?.let { file(it) }
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                keyPropsFile.exists() -> signingConfigs.getByName("release")
                // ⚠️ AÇIK KARAR: debug anahtarıyla imzalamak yasak değil,
                // SESSİZ olması yasak. Bayrakla istenirse build BİTER ve
                // uyarı basılır — bir kapı, koruduğu ürünün KENDİSİNİ
                // engellememelidir.
                allowDebugSigning -> signingConfigs.getByName("debug")
                // Aksi hâlde imzasız bırakılır; aşağıdaki kapı release
                // görevlerinde GradleException fırlatır.
                else -> null
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


// ⭐ SESSİZ-DÜŞME KAPISI — release görev grafiğinde ateşlenir.
//
// `signingConfig = null` tek başına yetmez: bazı görevler imzasız artefaktı
// sessizce üretebilir. Bu kapı, imza kimliği YOKKEN bir release artefaktının
// ÜRETİLMESİNİ adıyla durdurur.
//
// ⚠️ İKİ YÖNDE ölçülür (Lissom'un bulgusu): ötmesi gerekende ötüyor mu VE
// ötmemesi gerekende susuyor mu. `-PallowDebugSigning=true` verildiğinde
// build BİTMELİ — yalnız uyarı basmalı.
gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter {
        it.project == project && it.name.contains("Release")
    }
    if (releaseTasks.isEmpty()) return@whenReady

    val keyProps = rootProject.file("key.properties")
    val allowDebug =
        (project.findProperty("allowDebugSigning") as String?) == "true"

    if (keyProps.exists()) return@whenReady

    if (allowDebug) {
        logger.warn(
            "⚠️  RELEASE DEBUG ANAHTARIYLA İMZALANIYOR (-PallowDebugSigning). " +
            "Bu artefakt Play'e YÜKLENEMEZ; yerel deneme içindir."
        )
        return@whenReady
    }

    throw GradleException(
        "⛔ RELEASE İMZALANAMAZ: android/key.properties YOK.\n" +
        "   Şablonun eski hâli burada SESSİZCE debug anahtarına düşüyordu ve " +
        "üretilen artefakt Play tarafından reddedilirdi.\n" +
        "   · Gerçek imza: keystore + key.properties KURUCUDAN gelir " +
        "(sır; ~/.secrets/yula/, depoya ASLA).\n" +
        "   · Bilerek debug-imzalı yerel artefakt: " +
        "./gradlew :app:assembleRelease -PallowDebugSigning=true"
    )
}
