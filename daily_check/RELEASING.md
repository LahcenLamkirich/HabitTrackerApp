# Releasing Daily Check

Application ID / bundle ID: **`com.dailycheck.app`** (permanent — Play and the
App Store both key the listing to it, and it cannot be changed after the first
upload).

## 1. One-time: create the upload keystore

Release builds are signed with a key that only you hold. Run this once, from
the `android/` directory, and answer the prompts:

```sh
keytool -genkey -v -keystore upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

On Windows, `keytool` ships with the JDK bundled in Android Studio, e.g.:

```
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
in the passwords you just chose.

**Back up `upload-keystore.jks` and its passwords somewhere you will not lose
them.** If you lose the keystore you cannot ship an update to an existing
listing — you would have to publish a brand-new app and abandon your installs
and reviews. Enroll in Play App Signing when you first upload, which lets
Google reset a lost upload key.

Both `key.properties` and `*.jks` are gitignored. Keep it that way.

## 2. Build

Google Play wants an App Bundle, not an APK:

```sh
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

For sideloading or manual testing:

```sh
flutter build apk --release --split-per-abi
```

Use `--split-per-abi` for APKs: the universal APK is ~52 MB because it carries
every ABI, while each split is roughly a third of that. The App Bundle handles
this automatically, so no flag is needed for Play.

If `android/key.properties` is missing, the release build falls back to the
debug key and prints a warning. Such a build **cannot** be uploaded to Play.

## 3. Bump the version

`pubspec.yaml`, `version: 1.0.0+1` → the part after `+` is the Android
versionCode and the iOS build number. Play rejects a versionCode it has already
seen, so increment it on every upload.

## 4. iOS

`ios/Runner/PrivacyInfo.xcprivacy` declares that the app collects no data and
lists the required-reason APIs it touches. It is already registered in the
Xcode project's Runner target. **Verify on a Mac** that it appears under
Runner → Build Phases → Copy Bundle Resources, since the project file was
edited without Xcode to hand.

```sh
flutter build ipa --release
```

## 5. Store listing checklist

Both stores:

- [ ] Privacy policy hosted at a public URL — `PRIVACY.md` in this repo is the
      text, ready to paste into GitHub Pages, Notion or any static host
- [ ] App icon, screenshots (phone and tablet), short and full description
- [ ] Content rating questionnaire
- [ ] Data safety / App Privacy form: **no data collected, no data shared** —
      Daily Check has no servers, accounts or analytics
- [ ] Account deletion declaration: the app has no accounts; uninstalling
      deletes all local data, and Settings → Back up my habits lets a user
      take their data with them first

Play-specific:

- [ ] 512×512 icon, 1024×500 feature graphic
- [ ] targetSdk is 36, which satisfies Play's current requirement
- [ ] Permissions declared: notifications and run-at-startup only. The app
      deliberately does **not** request `SCHEDULE_EXACT_ALARM`; every reminder
      uses inexact scheduling, so no permitted-use justification is needed
