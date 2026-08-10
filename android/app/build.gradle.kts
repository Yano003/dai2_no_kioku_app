plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "jp.co.hitokoto.kiokuwo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications が新しい Java の日時 API を使うため、
        // 古い Android でも動くように脱糖（desugaring）を有効にする。
        // これが無いとビルドが通らない。
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // アプリケーション ID。**ストア公開後は変更できない。**
        // アプリ名「キオクヲ」の確定（2026/08/07）に合わせて確定させた。
        // ヒトコト株式会社様の実ドメインが jp.co.hitokoto と異なる場合は、
        // 初回申請前にここを合わせること。申請後は変更できない。
        applicationId = "jp.co.hitokoto.kiokuwo"
        // 対応 OS バージョンの下限。
        // 要件定義書 第2.0版 8章：目安として Android 9 以上。
        // 確認事項 No.6 のご回答は「他の一般的なアプリと同等」。
        //
        // Android 9 = API 28。本アプリが使う機能はいずれも API 28 で動作する。
        //   - 通知：POST_NOTIFICATIONS の実行時許可は API 33 以降のみの仕組みで、
        //           それ未満は既定で許可されている
        //   - 正確なアラーム：SCHEDULE_EXACT_ALARM の許可が要るのは API 31 以降で、
        //           それ未満は許可なしで正確なアラームを設定できる
        //   - 音声認識・端末内データベース：いずれも API 28 で動作する
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // 上の isCoreLibraryDesugaringEnabled と対で必要。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
