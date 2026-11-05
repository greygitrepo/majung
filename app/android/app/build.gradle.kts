import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 업로드 키 서명 정보. 비밀값이라 저장소 밖에 둔다 (tools/make_upload_key.sh 가 만든다).
// docker compose 의 release 서비스가 MAJUNG_KEY_PROPERTIES 로 위치를 알려 준다.
// 없으면 저장소 안 android/key.properties (gitignore 됨) 를 본다.
val keyPropertiesFile: File = System.getenv("MAJUNG_KEY_PROPERTIES")?.let { file(it) }
    ?: rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.isFile) keyPropertiesFile.inputStream().use { load(it) }
}
val hasUploadKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keyProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "kr.or.majung.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.or.majung.app"  // 확정. Play 첫 업로드 후 바꿀 수 없음 (docs/decisions.md #3)
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                // storeFile 이 상대 경로면 key.properties 가 있는 폴더 기준
                storeFile = keyPropertiesFile.parentFile.resolve(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 업로드 키가 없으면 debug 키로 서명해 `flutter run --release` 는 되게 둔다.
            // 다만 Play 에 올리는 .aab 는 아래 검사로 막는다.
            signingConfig = if (hasUploadKey) signingConfigs.getByName("upload")
                else signingConfigs.getByName("debug")
        }
    }
}

// debug 키로 서명된 .aab 를 Play 에 올리는 실수를 막는다.
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doFirst {
        if (!hasUploadKey) {
            throw GradleException(
                "업로드 키가 없습니다: ${keyPropertiesFile.path}\n" +
                    "tools/make_upload_key.sh 로 만든 뒤 " +
                    "`docker compose run --rm release` 로 빌드하세요."
            )
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
