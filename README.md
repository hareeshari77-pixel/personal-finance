# Personal Finance Tracker V2 — reconciled import

This offline Flutter project is rebuilt from the accompanying Excel workbook.

- Preserves the 1-Jan-2025 opening balances for bank/cash, credit cards, investments, and receivables.
- Retains all 2,678 Data-ledger rows through 15-Aug-2026.
- Calculates every balance from opening balance plus Receipt minus Payment, with separate investment and loan/receivable movement rules.
- Keeps two-sided transfer records and links only deterministic pairs.
- Includes an in-app Excel Reconciliation screen and `MIGRATION_RECONCILIATION_REPORT.md`.

No workbook credentials or the workbook's password sheet are included.

## Build

Upload the project to GitHub and run **Actions → Build Android APK → Run workflow**. The workflow creates a modern Android wrapper and uploads the APK artifact.

For a local Flutter environment, run `flutter pub get` followed by `flutter build apk --release`.
