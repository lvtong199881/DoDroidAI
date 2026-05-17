plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.serialization)
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
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
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

  // Material Design
  implementation("com.google.android.material:material:1.12.0")

  // Lifecycle
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.lifecycle.viewmodel.ktx)

  // Network
  implementation(libs.okhttp)
  implementation(libs.okhttp.logging)
  implementation(libs.retrofit)
  implementation(libs.kotlinx.serialization.json)

  // DataStore
  implementation(libs.datastore.preferences)

  // Markdown
  implementation("io.noties.markwon:core:4.6.2")
}