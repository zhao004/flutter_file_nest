plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名经环境变量注入：CI 在构建前把 keystore 还原到临时路径并设置以下变量；
// 本地未配置时回退 debug 签名，保证 `flutter run --release` 仍可用。
val releaseKeystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")
val hasReleaseSigning = !releaseKeystorePath.isNullOrBlank()

// 发布瘦身开关（仅在构建侧载 APK 时由 CI 设置，本地默认关闭）：
// - ANDROID_TARGET_ABI：只打包指定 ABI。`flutter build apk --target-platform`
//   只裁剪引擎与 Dart AOT 产物，插件自带的多架构 .so（如 media_kit 的
//   libmpv）仍会全部进包，必须在此过滤。
// - ANDROID_LEGACY_PACKAGING：按旧式策略压缩 APK 内的 .so，减小下载体积，
//   代价是安装时解压、安装后磁盘占用略增；Play 分发的 AAB 保持默认策略。
val targetAbi: String? = System.getenv("ANDROID_TARGET_ABI")?.takeIf { it.isNotBlank() }
val legacyPackaging = System.getenv("ANDROID_LEGACY_PACKAGING") == "true"

android {
    namespace = "com.zhao.filenest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zhao.filenest"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (targetAbi != null) {
            ndk {
                abiFilters.clear()
                abiFilters.add(targetAbi)
            }
        }
    }

    packaging {
        // 仅 CI 构建侧载 APK 时开启压缩；debug 等其余构建沿用 AGP
        // 默认策略（debuggable 变体默认按旧式压缩，不覆盖其行为）。
        if (legacyPackaging) {
            jniLibs {
                useLegacyPackaging = true
            }
        }
    }

    androidResources {
        // 应用仅提供中文与英文；剔除三方库其余语言的翻译资源。
        localeFilters += listOf("zh", "en")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // 收缩 Java/Kotlin 代码与资源；Flutter 引擎与 Media3 等自带
            // consumer 规则，项目侧规则见 proguard-rules.pro。
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.core:core-ktx:1.13.1")
    // sora-editor：应用内文本/代码编辑器（平台视图）。
    implementation("io.github.rosemoe:editor:0.24.6")
}
