# Release builds

Enso is signed with your own upload key. The key and its passwords stay on
your computer: `android/key.properties`, `*.jks` and `*.keystore` are
git-ignored, and nothing in the repo contains them.

## 1. Create an upload key (once)

```sh
keytool -genkey -v -keystore ~/enso-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias enso
```

Keep the `.jks` file and its passwords somewhere safe (a password manager).
If you lose them you can't publish updates under the same key.

## 2. Point the build at it

Copy `android/key.properties.example` to `android/key.properties` and fill it
in:

```properties
storePassword=…
keyPassword=…
keyAlias=enso
storeFile=/Users/you/enso-release.jks
```

Without this file, release builds are signed with the debug key so that
`flutter run --release` still works on your phone. Those builds can't be
published.

## 3. Build

```sh
flutter test && flutter analyze
flutter build appbundle --release   # for Google Play: build/app/outputs/bundle/release/app-release.aab
flutter build apk --release         # to install directly: build/app/outputs/flutter-apk/app-release.apk
```

Install the APK on a connected phone with `flutter install --release`.

## Version numbers

`version:` in `pubspec.yaml` is `name+code`, for example `1.0.0+1`. Raise the
code (`+2`, `+3`, …) for every build you upload; raise the name when users
should see a new version.

## Before publishing

- Test on a real phone with `flutter run --profile` (smoothness) and
  `--release` (exactly what users get).
- Exact alarms: Enso asks for "Alarms & reminders" (`SCHEDULE_EXACT_ALARM`)
  on Android 14+. Google Play asks apps that use it to declare why in the
  Play Console; for Enso it's "reminders at a time the user chose".
- The notification icon and sound are kept in release builds by
  `android/app/src/main/res/raw/keep.xml`.
