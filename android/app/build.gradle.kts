plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
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
        val keystoreFile = file("upload-keystore.jks")
        if (keystoreFile.exists()) {
            create("release") {
                storeFile = keystoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_keystore_password"
                keyAlias = System.getenv("KEY_ALIAS") ?: "upload"
                keyPassword = System.getenv("KEY_PASSWORD") ?: "your_key_password"
            }
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
        
        create("galeriaKazimierzNew") {
            dimension = "company"
            applicationId = "com.skanujwygrywaj.skanuj_wygrywaj"
            resValue("string", "app_name", "Galeria Kazimierz New")
            buildConfigField("String", "FLAVOR_NAME", "\"skanujNew\"")
        }

        create("polbauDemo"){
            dimension = "company"
            applicationId = "com.polbau.polbau"
            resValue("string", "app_name", "Moja Galeria")
            buildConfigField("String", "FLAVOR_NAME", "\"polbauDemo\"")
        }

        create("wislanka"){
            dimension = "company"
            applicationId = "com.wislanka.wislanka"
            resValue("string", "app_name", "Wislanka")
            buildConfigField("String", "FLAVOR_NAME", "\"wislanka\"")
        }

        create("staryBrowar"){
            dimension = "company"
            applicationId = "com.starybrowar.stary_browar"
            resValue("string", "app_name", "Stary Browar")
            buildConfigField("String", "FLAVOR_NAME", "\"staryBrowar\"")
        }
    }

    buildTypes {
        release {
            val releaseSigningConfig = signingConfigs.findByName("release")
            if (releaseSigningConfig != null) {
                signingConfig = releaseSigningConfig
            } else {
                // Use debug signing if keystore not found (for testing)
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
