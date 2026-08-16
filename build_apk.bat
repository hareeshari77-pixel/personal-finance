@echo off
flutter pub get
flutter build apk --release
echo APK: build\app\outputs\flutter-apk\app-release.apk
pause
