# BiteWise — Setup Guide (Milestone 1)

## 1. Prerequisites

- Flutter SDK (latest stable): https://docs.flutter.dev/get-started/install
- A Google account for Firebase

## 2. Generate platform folders

This repo contains the Dart source, `pubspec.yaml`, and config. Generate the
Android/iOS platform folders in place:

```bash
cd BiteWise
flutter create . --org com.bitewise --project-name bitewise
flutter pub get
```

> `flutter create .` only adds missing platform folders; it won't touch `lib/`.

## 3. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project** → name it `BiteWise`.
2. Enable **Google Analytics** (recommended).

## 4. Connect the app to Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Select your Firebase project and the platforms (android, ios). This generates
`lib/firebase_options.dart` and platform config files.

Then update `lib/main.dart` to pass the generated options:

```dart
import 'firebase_options.dart';
// in _initFirebase():
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

## 5. Enable services in the Firebase console

- **Authentication → Sign-in method**: enable **Email/Password** and **Google**.
- **Firestore Database**: create database (production mode), pick a region
  close to your users (this cannot be changed later).
- **Firestore Rules**: paste the contents of `firestore.rules` and publish.

## 6. Google Sign-In platform setup

**Android**
1. Get your SHA-1: `cd android && ./gradlew signingReport`
2. Firebase console → Project settings → your Android app → add the SHA-1.
3. Re-download `google-services.json` into `android/app/` (flutterfire usually handles this).

**iOS**
1. In `ios/Runner/Info.plist`, add the reversed client ID from
   `GoogleService-Info.plist` as a URL scheme.

## 7. Run

```bash
flutter run
```

Without Firebase configured the app shows a setup screen instead of crashing.
Once configured, you'll get the full auth flow → verified email → main app.

## Milestone 2 additions (Home Feed)

- **Re-publish rules**: `firestore.rules` now covers posts, likes, bookmarks,
  and follows — paste the updated file into the console again.
- **Composite index**: the Following feed query (`authorId in [...] +
  orderBy createdAt desc`) needs an index. Easiest path: run the app, tap the
  Following tab, and open the index-creation link Firestore prints in the
  console/logs. The For You feed needs no custom index.

## Milestone 3 additions (Post Creation)

1. **Enable Firebase Storage**: console → Build → Storage → Get started
   (same region as Firestore). Paste `storage.rules` and publish.
2. **Re-publish `firestore.rules`** (now includes restaurants).
3. **Run `flutter pub get`** (new deps: firebase_storage, image_picker,
   flutter_image_compress, uuid).
4. **iOS permissions** — add to `ios/Runner/Info.plist`:

   ```xml
   <key>NSPhotoLibraryUsageDescription</key>
   <string>BiteWise needs access to your photos so you can share food experiences.</string>
   <key>NSCameraUsageDescription</key>
   <string>BiteWise uses the camera to capture your dishes.</string>
   ```

   Android needs no manifest changes (image_picker uses the system photo picker).
5. **Composite index**: restaurant search uses a range query on `nameLower`
   only — no custom index needed.

## Milestone 4 additions (Restaurant Profiles)

- **Re-publish `firestore.rules`** (restaurant followers + follow counts).
- **Composite index**: restaurant posts query (`restaurantId == X` +
  `orderBy createdAt desc`) needs one — open a restaurant profile once and
  follow the index link Firestore prints in the logs.

## Milestone 5 additions (Comments + Post Detail)

- **Re-publish `firestore.rules`** (comments + comment counters). No new
  indexes: comments order by `createdAt` only.

## Milestone 6 additions (User Profiles + Follow)

- **Re-publish `firestore.rules`** (user followers + follow counters).
- **Composite index**: user posts query (`authorId == X` + `orderBy createdAt
  desc`) needs one — open any profile with posts once and follow the index
  link in the logs. (Same index also serves the Following feed's whereIn
  variant if prompted.)
- `storage.rules` already covers avatars — no storage change needed.

## Milestone 7 additions (Search + Explore)

- **Run `flutter pub get`** (new dep: shared_preferences).
- **Composite index**: tag search (`tags array-contains X` + `orderBy
  createdAt desc`) needs one — search any #tag once and follow the index
  link in the logs. Trending (orderBy likeCount) and prefix searches use
  automatic single-field indexes.
- No rules changes (read-only queries).

## Milestone 8 additions (Cloud Functions backend)

Counters, denormalization, and trending are now server-side.

1. **Upgrade to the Blaze plan** (pay-as-you-go) in the Firebase console —
   required for Cloud Functions. Free tier quotas still apply.
2. **Install tooling** (Node 20 required):

   ```bash
   npm install -g firebase-tools
   firebase login
   firebase use --add        # select your project, alias "default"
   cd functions && npm install && cd ..
   ```

3. **Deploy everything**:

   ```bash
   firebase deploy --only functions,firestore:rules,storage
   ```

4. **Re-publish rules note**: counters are now fully locked for clients —
   deploy the rules together with (or before) shipping this app version,
   otherwise old clients' counter writes will start failing (their like/
   follow edge writes still succeed; only the redundant counter bump is
   rejected, and Functions maintain the true counts).
5. **New index**: trending now orders by `trendingScore` (single-field,
   automatic). Top Rated orders by `ratingAvg` (single-field, automatic).
6. **Local testing** (optional): `firebase emulators:start` runs Auth,
   Firestore, Functions, and Storage locally.

## Milestone 9 additions (Notifications)

1. **Run `flutter pub get`** (new dep: firebase_messaging).
2. **Deploy**: `firebase deploy --only functions,firestore:rules`.
3. **Android**: no manifest changes needed for basic delivery. Android 13+
   runtime permission is requested in-app automatically.
4. **iOS (when you set up the iOS build)**:
   - Enable *Push Notifications* + *Background Modes → Remote notifications*
     capabilities in Xcode.
   - Upload your APNs auth key in Firebase console → Project settings →
     Cloud Messaging.
5. **New index**: notifications query `read == false` + default ordering is
   single-field (automatic). The unread-badge query needs no index.

## Milestone 10 additions (Messaging)

- **Deploy**: `firebase deploy --only functions,firestore:rules,storage`.
- **Composite index**: chat list (`participants array-contains me` +
  `orderBy updatedAt desc`) — open the Messages tab once and follow the
  index link in the logs.

## Milestone 11 additions (Reservations)

- **Deploy**: `firebase deploy --only functions,firestore:rules`.
- **Composite index**: my-reservations query (`userId == me` + `orderBy
  dateTime desc`) — open the Reservations screen once and follow the index
  link. (A `restaurantId + dateTime` index will be needed when the owner
  dashboard ships.)

## Milestone 12 additions (Nearby Map)

1. **Run `flutter pub get`** (new deps: google_maps_flutter, geolocator).
2. **Create a Google Maps API key**:
   - Go to https://console.cloud.google.com/google/maps-apis (select project
     `bitewise-1d266` — Firebase projects are Google Cloud projects).
   - Enable **Maps SDK for Android** and **Maps SDK for iOS**.
   - Google Maps Platform requires a **billing account** (generous free
     monthly usage tiers apply; typical dev usage costs nothing).
   - Create separate restricted keys: Android package
     `com.bitewise.bitewise`, and iOS bundle `com.amansaleem06.bitewise`.
3. **Places REST key (restaurant search)** — never committed to the repo:
   - Enable **Places API (New)**; create a key restricted to that API only.
   - Local runs: `flutter run --dart-define=PLACES_API_KEY=AIza...`
   - CI: add `PLACES_API_KEY` as a **secure** variable in Codemagic;
     `codemagic.yaml` passes it into the build automatically.
   - Full policy: `docs/SECURITY.md`.
3. **Configure separate restricted keys**:
   - Android key in `android/app/src/main/AndroidManifest.xml`
   - iOS key in `ios/Runner/AppDelegate.swift`
4. Rebuild (`RUN_BITEWISE.bat`). Restaurants created from now on capture
   the creator's location and appear on the Nearby map.

## App Store readiness checklist

### No Mac? Use Codemagic
See **[NO_MAC_RELEASE.md](NO_MAC_RELEASE.md)** for the full Windows → GitHub →
Codemagic → TestFlight path.

### Done in the repo
- Account deletion: Profile → Settings → Delete account (+ Cloud Function
  cascade `onAuthUserDeleted`)
- Privacy Policy + Terms screens (also linked on Welcome)
- Static legal pages in `docs/` for GitHub Pages
- iOS Google Sign-In URL scheme in `Info.plist`
- `GoogleService-Info.plist`, `Runner.entitlements` (Push + Sign in with Apple),
  `PrivacyInfo.xcprivacy`
- `ITSAppUsesNonExemptEncryption` = false
- Firestore rule allows self-delete of `users/{uid}`
- Separate restricted Android and iOS Maps client keys are configured

### You still must do outside the repo
Follow [NO_MAC_RELEASE.md](NO_MAC_RELEASE.md). Short version:
1. Apple Developer + App Store Connect app + API key
2. Push to GitHub + enable Pages on `/docs`
3. Codemagic + `bitewise_asc` + `APP_STORE_APPLE_ID`
4. Firebase Apple Sign-In + APNs; `firebase deploy --only functions,firestore:rules`
5. Replace app icons; TestFlight → App Review
