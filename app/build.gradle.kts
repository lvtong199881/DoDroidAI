plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.serialization)
  id("com.google.devtools.ksp")
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

android {
    namespace = "com.example.dodroidai"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.example.dodroidai"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    signingConfigs {
        create("release") {
            val envStoreFile = System.getenv("RELEASE_STORE_FILE")
            if (!envStoreFile.isNullOrBlank()) {
                storeFile = file(envStoreFile)
                storePassword = System.getenv("RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("RELEASE_KEY_PASSWORD")
            } else {
                // 本地/CI 无 secret 时回退仓库测试 keystore，仅用于测试出包
                storeFile = rootProject.file("keystore/release.keystore")
                storePassword = "DodroidAI2024"
                keyAlias = "dodroid"
                keyPassword = "DodroidAI2024"
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }
    lint {
        abortOnError = false
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
      resources {
        excludes += "/META-INF/{AL2.0,LGPL2.1}"
      }
    }

}

kotlin {
    jvmToolchain(17)
}

dependencies {
  // Core Android dependencies
  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.appcompat)
  implementation(libs.androidx.activity)
  implementation(libs.androidx.constraintlayout)
  implementation(libs.androidx.splashscreen)

  // Material Design
  implementation("com.google.android.material:material:1.12.0")

  // Lifecycle
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.lifecycle.viewmodel.ktx)

  // Network
  implementation(libs.okhttp)
  implementation(libs.okhttp.sse)
  implementation(libs.okhttp.logging)
  implementation(libs.kotlinx.serialization.json)

  // DataStore
  implementation(libs.datastore.preferences)

  // Gson for JSON parsing
  implementation(libs.gson)
  implementation(libs.room.runtime)
  implementation(libs.room.ktx)
  implementation(libs.work.runtime.ktx)
  ksp(libs.room.compiler)
  ksp(project(":tool-processor"))

  // Markdown
  implementation("io.noties.markwon:core:4.6.2")
  implementation("io.noties.markwon:ext-tables:4.6.2")
  implementation("io.noties.markwon:ext-strikethrough:4.6.2")

  // Attachments
  implementation("com.tom-roush:pdfbox-android:2.0.27.0")
  implementation("androidx.exifinterface:exifinterface:1.4.1")
  implementation("io.coil-kt.coil3:coil:3.2.0")

  // Unit tests
  testImplementation("junit:junit:4.13.2")

  // Internal modules
  implementation(project(":webview-sdk"))
}