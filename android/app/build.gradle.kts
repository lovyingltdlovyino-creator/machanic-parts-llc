import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
  namespace = "com.mechanicpart.mechanic_part"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = "27.0.12077973"

  // Load signing properties if present
  val keystorePropertiesFile = rootProject.file("key.properties")
  val keystoreProperties = Properties()
  if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    // Required by some libraries (e.g., flutter_local_notifications)
    isCoreLibraryDesugaringEnabled = true
  }

  kotlinOptions {
    jvmTarget = JavaVersion.VERSION_11.toString()
  }

  defaultConfig {
    // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "com.mechanicpart.mechanic_part"
    // You can update the following values to match your application needs.
    // For more information, see: https://flutter.dev/to/review-gradle-config.
    // purchases_flutter 9.x requires minSdk 24
    minSdk = maxOf(flutter.minSdkVersion, 24)
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }

  signingConfigs {
    create("release") {
      val storeFileProp = keystoreProperties.getProperty("storeFile")
      if (!storeFileProp.isNullOrBlank()) {
        val normalized = storeFileProp
          .removePrefix("android/app/")
          .removePrefix("android/")
          .removePrefix("app/")

        val candidates = listOf(
          file(storeFileProp),
          file(normalized),
          rootProject.file(storeFileProp),
          rootProject.file(normalized),
          rootProject.file("app/$normalized")
        ).distinct()

        val found = candidates.firstOrNull { it.exists() }
        if (found != null) {
          storeFile = found
        }
      }
      storePassword = keystoreProperties.getProperty("storePassword")
      keyAlias = keystoreProperties.getProperty("keyAlias")
      keyPassword = keystoreProperties.getProperty("keyPassword")
    }
  }

  buildTypes {
    release {
      // Use release signing if configured, otherwise fall back to debug for local builds
      val releaseConfig = signingConfigs.findByName("release")
      signingConfig = if (releaseConfig?.storeFile != null && releaseConfig.storeFile!!.exists()) {
        releaseConfig
      } else {
        signingConfigs.getByName("debug")
      }
      // Enable R8 if you want (keep false until you add proper rules)
      isMinifyEnabled = false
      // Resource shrinking requires code shrinking; keep disabled while minify is false
      isShrinkResources = false
    }
  }
}

flutter {
  source = "../.."
}

dependencies {
  // Core library desugaring support
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
