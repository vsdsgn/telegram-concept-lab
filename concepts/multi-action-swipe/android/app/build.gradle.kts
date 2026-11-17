plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "lab.telegramconcept.multiswipe"
    compileSdk = 36

    defaultConfig {
        applicationId = "lab.telegramconcept.multiswipe"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1-concept"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.recyclerview:recyclerview:1.4.0")
    implementation("androidx.dynamicanimation:dynamicanimation:1.1.0")
    testImplementation("junit:junit:4.13.2")
}
