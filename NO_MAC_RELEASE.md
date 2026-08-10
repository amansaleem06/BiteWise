# Ship BiteWise to the App Store without a Mac

You build on **Windows**. A cloud Mac (**Codemagic**) signs the iOS app and
uploads it to **TestFlight**. You never need Xcode on your PC.

```
Your PC → GitHub → Codemagic (Mac) → App Store Connect → TestFlight → App Review
```

---

## 0. Checklist (print this)

- [ ] Apple Developer Program enrolled (~$99/year)
- [ ] App created in App Store Connect (`com.amansaleem06.bitewise`)
- [ ] App Store Connect API key created
- [ ] GitHub repo created + this code pushed
- [ ] GitHub Pages enabled for `/docs`
- [ ] Legal URLs updated in `lib/core/constants/app_legal.dart`
- [ ] Codemagic connected to GitHub
- [ ] Codemagic App Store Connect integration named `bitewise_asc`
- [ ] `APP_STORE_APPLE_ID` set in Codemagic
- [ ] Firebase: Sign in with Apple ON + APNs key uploaded
- [ ] `firebase deploy --only functions,firestore:rules`
- [ ] First `ios-release` build green → build visible in TestFlight

---

## 1. Apple Developer Program

1. Go to [https://developer.apple.com/programs/](https://developer.apple.com/programs/)
2. Enroll with the Apple ID you will use for the store.
3. Wait until membership shows **Active** (can take hours–days).

Without this, Codemagic cannot sign or upload.

---

## 2. Create the app in App Store Connect

1. Open [https://appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. Platforms: **iOS**
4. Name: **BiteWise**
5. Bundle ID: select `com.amansaleem06.bitewise`
6. SKU: e.g. `bitewise001`
7. After creation, open **App Information** and copy the numeric **Apple ID**
   (looks like `6750123456`). You will paste this into Codemagic as
   `APP_STORE_APPLE_ID`.

### App Store Connect API key (for Codemagic)

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**
2. **Generate** a key with **App Manager** access
3. Download the `.p8` file **once** — store it safely
4. Note **Issuer ID** and **Key ID**

---

## 3. Put the project on GitHub

On your Windows PC (PowerShell), from the `BiteWise` folder:

```powershell
cd C:\Users\Lenovo\BiteWise\BiteWise

# If git is already initialized (it should be):
git add .
git status
git commit -m "Prepare BiteWise for Codemagic iOS release"

# Create an empty repo on GitHub named "bitewise" (no README), then:
git remote add origin https://github.com/amansaleem06/bitewise.git
git branch -M main
git push -u origin main
```

If the remote already exists, just:

```powershell
git push -u origin main
```

### Enable GitHub Pages (Privacy + Terms URLs)

1. GitHub repo → **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: `main` / folder: **/docs**
4. Save

Your public URLs are:

- `https://amansaleem06.github.io/bitewise/privacy.html`
- `https://amansaleem06.github.io/bitewise/terms.html`

These are already set in `lib/core/constants/app_legal.dart`.

In App Store Connect → App Privacy / App Information, paste the **privacy** URL.

---

## 4. Codemagic (cloud Mac build)

1. Sign up at [https://codemagic.io](https://codemagic.io) with GitHub
2. **Add application** → select the `bitewise` repo → Flutter
3. Codemagic should detect `codemagic.yaml`

### App Store Connect integration

1. Codemagic → **Teams** → **Integrations** → **App Store Connect**
2. Add the API key (Issuer ID, Key ID, `.p8`)
3. Name it exactly: **`bitewise_asc`**

### Environment variables

In the Codemagic application → **Environment variables**:

| Variable | Value | Secret? |
|----------|--------|---------|
| `APP_STORE_APPLE_ID` | Numeric Apple ID from step 2 | No |

Also update the placeholder in `codemagic.yaml` or override via UI variables
(Codemagic UI vars take precedence for many setups — set both to be safe).

### Run the iOS build

1. Select workflow **ios-release**
2. **Start new build**
3. When green: open App Store Connect → **TestFlight** — the build appears
   after Apple processing (often 5–30 minutes)

Install TestFlight on your iPhone and add yourself as an internal tester.

---

## 5. Firebase (iOS push + Apple Sign-In)

1. [Firebase Console](https://console.firebase.google.com) → project `bitewise-1d266`
2. **Authentication** → Sign-in method → enable **Apple**
3. Apple Developer → **Certificates, Identifiers & Profiles** → Keys → create
   a key with **Apple Push Notifications service (APNs)**
4. Firebase → Project settings → **Cloud Messaging** → upload that APNs key
5. From your PC (with Firebase CLI logged in):

```powershell
cd C:\Users\Lenovo\BiteWise\BiteWise
firebase deploy --only functions,firestore:rules
```

---

## 6. Google Maps API key

1. [Google Cloud Console](https://console.cloud.google.com/) → same project as Firebase
2. Enable **Maps SDK for iOS** and **Maps SDK for Android**
3. Create an API key; restrict it to those APIs and package
   `com.amansaleem06.bitewise` for iOS and `com.bitewise.bitewise` for Android
4. Confirm the Android and iOS keys remain restricted in Google Cloud. The
   client keys are configured in AndroidManifest.xml and AppDelegate.swift.

---

## 7. Before App Review (after TestFlight works)

1. App Store Connect listing: description, keywords, support URL, privacy URL
2. Screenshots (6.7" and 6.1" iPhone) — capture from TestFlight device
3. Replace default Flutter app icons under
   `ios/Runner/Assets.xcassets/AppIcon.appiconset`
4. In `codemagic.yaml`, set `submit_to_app_store: true` only when you want
   Codemagic to send the build to App Review automatically — or submit
   manually from App Store Connect

---

## Common failures

| Symptom | Fix |
|---------|-----|
| Signing / profile errors | Confirm Apple membership Active; Codemagic ASC integration name is `bitewise_asc` |
| `APP_STORE_APPLE_ID` upload fail | Paste the **numeric** Apple ID, not the bundle id |
| Google Sign-In fails on device | Confirm `GoogleService-Info.plist` is in the repo and URL scheme is in Info.plist |
| Push never arrives | APNs key missing in Firebase |
| Map is blank | Confirm billing, SDK enablement, and key restrictions in Google Cloud |
| Analyze fails the build | Fix analyzer errors locally with `flutter analyze` before pushing |

---

## What you do next (right now)

1. Enroll / confirm **Apple Developer** membership (~$99/year).
2. On GitHub, create an **empty** repo named `bitewise` (no README), then:

```powershell
cd C:\Users\Lenovo\BiteWise\BiteWise
git remote add origin https://github.com/amansaleem06/bitewise.git
git push -u origin main
```

3. Enable **GitHub Pages** on branch `main` / folder `/docs`.
4. Reply here when Apple membership is **Active** so we can continue with
   App Store Connect + Codemagic TestFlight.
