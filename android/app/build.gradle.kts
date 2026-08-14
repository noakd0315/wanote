import java.util.Properties

// Upload-key credentials, kept out of the repository.
//
// android/key.properties is gitignored and holds the keystore path and its
// passwords. It is absent on a fresh clone and in CI, which is why every use
// below is guarded: a missing file must still leave `flutter run --release`
// working for day-to-day device testing. Only the Play upload actually needs
// the real key.
//
// See docs/CLOSED_TEST_GUIDE.md for how to create the keystore.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "jp.wanote.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time to
        // schedule reminders. Without it the Android build fails outright
        // ("Dependency ':flutter_local_notifications' requires core library
        // desugaring to be enabled for :app").
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "jp.wanote.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // The upload key when it is available, the debug key otherwise.
            //
            // Falling back rather than failing is deliberate: device testing
            // runs `flutter run --release` constantly and must not require
            // the signing key to be present. Play rejects debug-signed
            // bundles, so an accidental debug-signed upload cannot slip
            // through unnoticed -- it is refused at the door.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 runs on release builds, and until now it ran with no rules
            // of our own. That shipped a release APK that died on launch --
            // see proguard-rules.pro for what it stripped and why.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Backports the java.time APIs that flutter_local_notifications needs on
    // older Android releases; pairs with isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
