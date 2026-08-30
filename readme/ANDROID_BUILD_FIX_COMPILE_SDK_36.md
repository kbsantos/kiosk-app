# Android APK build fix — compileSdk 36

The current Android build fails because `flutter_plugin_android_lifecycle` requires apps using it to compile against Android API 36 or newer, while `file_picker` is compiled against API 34.

## Required change

In `android/app/build.gradle` (or `android/app/build.gradle.kts`), change only the **compileSdk** value to 36.

### Groovy

```gradle
android {
    compileSdk 36
}
```

or:

```gradle
android {
    compileSdk = 36
}
```

Do **not** change `minSdk` just for this error. `targetSdk` can remain at the existing value unless you have a separate requirement to raise it.

## Build

```bash
flutter clean
rm -rf .dart_tool
flutter pub get
flutter build apk --release
```

If API 36 is not installed:

```bash
sdkmanager "platforms;android-36"
```

## Automated patch

From the project root:

```bash
./apply_android_compile_sdk_36_fix.sh
```

The script creates a `.bak` copy of the Android build file before changing `compileSdk`.
