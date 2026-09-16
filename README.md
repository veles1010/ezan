# Ezan Zamanı

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
Codex write test

## App icon and splash assets

Add these PNG files before generating Android and iOS icon/splash files:

- `assets/icons/app_icon.png`
- `assets/splash/splash_logo.png`

Then run:

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## iOS AdMob release configuration

Before an iOS Release build, create the ignored
`ios/Flutter/AdMob-Release.xcconfig` file with the production iOS App ID:

```xcconfig
ADMOB_IOS_APP_ID = <production iOS AdMob App ID>
```

Pass the production iOS banner unit ID only at build time:

```bash
flutter build ios --release \
  --dart-define=ADMOB_IOS_BANNER_AD_UNIT_ID=<production iOS banner ad unit ID>
```
