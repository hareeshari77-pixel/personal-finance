# Build the APK with GitHub Actions

This project is configured so GitHub Actions generates a fresh modern Android
project automatically before compiling. You do not need Android Studio.

## One-time setup

1. Upload the project files to your GitHub repository.
2. Make sure `.github/workflows/build-apk.yml` is present.
3. Commit to `main`.

## Build

Open **Actions → Build Android APK → Run workflow → Run workflow**.

The workflow:
- installs Flutter
- creates a current Android project using Flutter's modern Android embedding
- installs dependencies
- builds the release APK
- uploads the APK as an artifact

## Download

Open the successful workflow run and download the artifact:
`personal-finance-tracker-v2-reconciled-apk`

Extract it and install `app-release.apk` on Android.

No Supabase or cloud backend is required.
