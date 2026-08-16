# Personal Finance Tracker V1

Offline-first Android finance tracker prototype.

## Build
This is a complete Flutter project. If Flutter/Android SDK are installed:
1. `flutter pub get`
2. `flutter build apk --release`
3. APK: `build/app/outputs/flutter-apk/release/app-release.apk`

The app stores data locally using SharedPreferences in this V1 prototype.

## V1 features
- Dashboard
- Accounts: bank, credit card, cash, wallet
- Income, expense, investment and transfer transactions
- Custom categories/subcategories
- Search and filters
- Net worth calculation
- Credit-card outstanding
- Monthly expense breakdown
- Add/edit/delete transactions
- Local offline storage


## Easiest APK build

This project includes `.github/workflows/build-apk.yml`. Upload the project contents to a GitHub repository and GitHub Actions will build a release APK automatically. See `BUILD_APK_WITH_GITHUB.md` for the exact steps.
