plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jiny.hmlove"
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
        applicationId = "com.jiny.hmlove"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

val generatedRegistrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
val javaDir = file("src/main/java")

tasks.withType<JavaCompile>().configureEach {
    // Flutter regenerates this file into src/main/java, but compiling it
    // directly can fail for some plugin variants. We provide our own
    // reflective registrant from src/main/kotlin instead.
    // After deleting, also remove the empty java directory to avoid
    // "no source files" javac error.
    doFirst {
        if (generatedRegistrant.exists()) {
            generatedRegistrant.delete()
        }
        if (javaDir.exists() && javaDir.walkTopDown().none { it.isFile }) {
            javaDir.deleteRecursively()
        }
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    doFirst {
        if (generatedRegistrant.exists()) {
            generatedRegistrant.delete()
        }
        if (javaDir.exists() && javaDir.walkTopDown().none { it.isFile }) {
            javaDir.deleteRecursively()
        }
    }
}
