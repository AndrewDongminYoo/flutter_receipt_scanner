plugins {
    id("com.android.library")
    // Applied without a version: AGP + Kotlin come from the consuming app's
    // settings pluginManagement (the example resolves AGP 9.0.1 / Kotlin 2.3.20),
    // so nothing is pinned here. Declaring it explicitly also wires the Kotlin
    // unit-test compilation (compileDebugUnitTestKotlin). Flutter nudges toward
    // "built-in Kotlin" instead, but that broader migration is left for later.
    id("org.jetbrains.kotlin.android")
}

group = "com.example.flutter_receipt_scanner_android"
version = "0.1.0"

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

android {
    namespace = "com.example.flutter_receipt_scanner_android"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
    // Korean recognizer covers Latin too; pinned 16.0.1 (rotation-invariance
    // validated on 16.0.0 — see the native port map §6.4). A different version
    // can silently break the single-pass autoRotate heuristic.
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    implementation("androidx.activity:activity-ktx:1.10.1")
    testImplementation("junit:junit:4.13.2")
}
