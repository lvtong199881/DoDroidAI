plugins {
  alias(libs.plugins.android.application) apply false
  alias(libs.plugins.android.library) apply false
  alias(libs.plugins.kotlin.serialization) apply false
  id("org.jetbrains.kotlin.jvm") version "2.0.21" apply false
  id("com.google.devtools.ksp") version "2.0.21-1.0.28" apply false
}