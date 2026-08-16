# Build the APK with GitHub Actions

## One-time setup

1. Create/sign in to GitHub.
2. Create a new repository, for example `personal-finance-tracker`.
3. Upload **all files and folders inside this project** to the repository.
   - Do not upload the ZIP itself as the project.
   - Make sure `.github/workflows/build-apk.yml` is present.
4. Commit the files to the `main` branch.

## Build

After the upload, GitHub should automatically start the workflow.

If it does not:
1. Open the repository.
2. Click **Actions**.
3. Click **Build Android APK**.
4. Click **Run workflow**.
5. Wait for the green check mark.

## Download

1. Open the completed workflow run.
2. Scroll to **Artifacts**.
3. Download `personal-finance-tracker-v1-apk`.
4. Extract the downloaded artifact.
5. Install `app-release.apk` on your Android phone.

## Notes

- This V1 is offline/local-first.
- No Supabase account or backend is required.
- GitHub Actions builds the APK; your financial data is not part of the repository unless you add it yourself.
