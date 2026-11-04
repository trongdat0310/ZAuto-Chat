# ZAutoChat.Pro Android Release Checklist

## 1. Quality gates

Run from `zauto_driver`:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

Run backend tests from `zauto-backend`:

```powershell
npm test
```

All commands must pass before producing a release artifact.

## 2. Production application ID

The Android application ID is currently:

```text
com.example.zauto_driver
```

Firebase `android/app/google-services.json` currently uses the same package name.

Do not change only one side. When assigning the final production package ID:

1. Change `applicationId` and `namespace` in `android/app/build.gradle.kts`.
2. Register the exact same Android package in Firebase.
3. Download the new `google-services.json`.
4. Replace `android/app/google-services.json`.
5. Re-run `flutter analyze`, `flutter test`, and a release build.

## 3. Release signing

Recommended setup from `zauto_driver`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\setup_release_signing.ps1
```

The script creates local-only:

- `android/app/zautochat-upload.jks`
- `android/key.properties`

Both are ignored by Git.

You can also configure signing manually by copying:

```text
android/key.properties.example
```

to:

```text
android/key.properties
```

and filling in the real upload-keystore values.

Never commit:

- `android/key.properties`
- `*.jks`
- `*.keystore`
- passwords

Back up the upload keystore securely. Future updates must be signed with the same key.

The release Gradle configuration does not silently fall back to the debug signing key.

## 4. Version

Update `pubspec.yaml` before publishing:

```yaml
version: 1.0.0+1
```

Increment the build number for every uploaded Android release.

## 5. Build

APK:

```powershell
flutter build apk --release
```

App Bundle for Google Play:

```powershell
flutter build appbundle --release
```

## 6. Verify, install and launch the release APK

Connect a real Android device with USB debugging enabled, then run from `zauto_driver`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\release_smoke.ps1
```

The script checks:

- the release APK exists
- APK signature validity with `apksigner`
- an authorized ADB device is connected
- APK installation succeeds
- the launcher activity starts
- the application process remains alive after launch

To verify the signature only:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\release_smoke.ps1 -SkipInstall
```

## 7. Manual smoke test on the installed release build

Verify on a real device:

- login/logout
- Zalo link/relink
- Home realtime reconnect
- notification listener
- foreground push notification
- Messages pin/unpin/delete
- unread/read sync
- Chat text send
- reply
- recall/delete
- photo album send
- image/video/file open
- background -> foreground
- network off -> on
- app restart

If a release-only crash occurs, capture logs with:

```powershell
adb logcat -c
adb logcat | Select-String "zauto|flutter|AndroidRuntime|FATAL EXCEPTION"
```
