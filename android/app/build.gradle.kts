import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

val releaseSigningRequiredProperties = listOf(
    "storePassword",
    "keyPassword",
    "keyAlias",
    "storeFile",
)
val missingReleaseSigningProperties = releaseSigningRequiredProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}.toMutableList()
val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let(rootProject::file)
if (releaseStoreFile != null && !releaseStoreFile.isFile) {
    missingReleaseSigningProperties += "keystore file referenced by storeFile"
}
val hasReleaseSigning = missingReleaseSigningProperties.isEmpty()

val admobAndroidAppId =
    System.getenv("ADMOB_ANDROID_APP_ID")
        ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.veles.ezanvakti"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.veles.ezanvakti"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["ADMOB_APP_ID"] = admobAndroidAppId
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = requireNotNull(releaseStoreFile)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    val task = taskName.substringAfterLast(':')
    task.contains("Release", ignoreCase = true) ||
        task.equals("assemble", ignoreCase = true) ||
        task.equals("build", ignoreCase = true)
}
if (releaseTaskRequested && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Missing or invalid: " +
            missingReleaseSigningProperties.joinToString(", ") +
            ". Provide android/key.properties and its keystore before building a release.",
    )
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
