plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pl.a2ti.galeriakazimierz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Base application ID - overridden by flavors
        applicationId = "pl.a2ti.galeriakazimierz"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_keystore_password"
            keyAlias = System.getenv("KEY_ALIAS") ?: "upload"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "your_key_password"
        }
    }

    flavorDimensions += "company"
    
    productFlavors {
        create("galeriaKazimierz") {
            dimension = "company"
            applicationId = "pl.a2ti.galeriakazimierz"
            resValue("string", "app_name", "Galeria Kazimierz")
            buildConfigField("String", "FLAVOR_NAME", "\"galeriaKazimierz\"")
        }
        
        create("kazimierzClub") {
            dimension = "company"
            applicationId = "pl.a2ti.kazimierzclub"
            resValue("string", "app_name", "Kazimierz Club")
            buildConfigField("String", "FLAVOR_NAME", "\"kazimierzClub\"")
        }
        
        create("skanujNew") {
            dimension = "company"
            applicationId = "com.skanujwygrywaj.skanuj_wygrywaj"
            resValue("string", "app_name", "Skanuj Wygrywaj")
            buildConfigField("String", "FLAVOR_NAME", "\"skanujNew\"")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
