# API Key Setup Guide — step by step

Exact clicks for the three key tasks before App Review, plus App Check after
launch. Everything happens in [Google Cloud Console](https://console.cloud.google.com)
(project **bitewise-1d266**) and [Codemagic](https://codemagic.io).

Your three keys, and what each is for:

| Key | Lives where | Used for |
|---|---|---|
| Places REST key | Codemagic secure variable + your own machine (never in git) | Restaurant search in Create / business claim |
| Maps SDK Android key (`AIzaSyC-qlh...`) | `AndroidManifest.xml` (committed — fine when restricted) | Nearby map on Android |
| Maps SDK iOS key (`AIzaSyCzQ_...`) | `AppDelegate.swift` (committed — fine when restricted) | Nearby map on iOS |

---

## Task 1 — Rotate the leaked Places key · do this NOW (~5 min)

The old key `AIzaSyBW-...` is in the public git history with no restrictions.
Anyone can use it and bill you. Deleting it from code is not enough — the key
itself must die.

1. Open <https://console.cloud.google.com/apis/credentials> and make sure the
   project selector (top bar) says **bitewise-1d266**.
2. In the **API keys** list, find the key whose value starts `AIzaSyBW-`
   (click **Show key** on each to compare).
3. Click the three-dot menu on that row → **Delete API key**. Confirm.
   *The leak is now dead — anything a stranger copied stops working.*
4. Click **+ Create credentials → API key**. Copy the new value immediately
   into a password manager.
5. The "API key created" dialog → **Edit API key** (or click its name in the
   list), then set:
   - **Name:** `BiteWise Places REST`
   - **Application restrictions:** `None` (REST calls from a phone can't be
     app-restricted; the API restriction below is the fence)
   - **API restrictions:** `Restrict key` → tick **Places API (New)** only
6. **Save**.

> When: immediately. The old key is exposed right now, launch or not.

---

## Task 2 — Give the new key to your builds (~5 min)

**Codemagic (TestFlight / App Store / Play builds):**

1. <https://codemagic.io> → your **BiteWise** app → **Settings** (⚙) →
   **Environment variables** tab.
2. Add a variable:
   - Name: `PLACES_API_KEY` (exactly this — `codemagic.yaml` reads it)
   - Value: the new key from Task 1
   - **Secure: checked** ✔ (encrypts it, hides it from logs)
   - Group: default / none is fine
3. Save. Nothing else — `codemagic.yaml` already passes it into both the iOS
   and Android build commands.

**Your own machine (day-to-day development):**

```powershell
flutter run --dart-define=PLACES_API_KEY=AIza...your-new-key
```

Tip: in VS Code / Cursor, put it in `.vscode/launch.json` under `args` so you
don't retype it (that folder is gitignored).

> When: before your next build. A build made without it just disables
> Google-powered search; nothing crashes.

---

## Task 3 — Restrict the two Maps SDK keys (~10 min)

These keys are in the repo, which is normal **only if** they're locked to your
app identities. Verify both at
<https://console.cloud.google.com/apis/credentials>:

**Android key (value starts `AIzaSyC-qlh`):**

1. Click its name → **Application restrictions:** `Android apps`.
2. **Add** an item:
   - Package name: `com.bitewise.bitewise`
   - SHA-1: your signing certificate fingerprint. Get it:
     - Debug/dev: `cd android; ./gradlew signingReport` → `SHA1:` line.
     - Play releases: Play Console → your app → **Test and release → Setup →
       App signing** → *App signing key certificate* SHA-1.
   - Add **both** debug and release SHA-1s (two entries, same package).
3. **API restrictions:** `Restrict key` → **Maps SDK for Android** only.
4. Save.

**iOS key (value starts `AIzaSyCzQ_`):**

1. Click its name → **Application restrictions:** `iOS apps`.
2. Add bundle ID: `com.amansaleem06.bitewise`.
3. **API restrictions:** `Restrict key` → **Maps SDK for iOS** only.
4. Save.

> When: before submitting for review. Test the Nearby map afterwards — a
> wrong SHA-1/bundle shows a blank grey map, which means the restriction is
> working but doesn't match your build signature.

---

## Task 4 — After launch: Firebase App Check + billing alarm

**App Check** makes Firebase reject requests that don't come from your genuine
app binaries — the single biggest security upgrade available:

1. [Firebase Console](https://console.firebase.google.com/project/bitewise-1d266)
   → **Build → App Check**.
2. Register the Android app with **Play Integrity** and the iOS app with
   **App Attest**.
3. Add the `firebase_app_check` package to the app, activate it at startup.
4. Run in **monitor mode** first; only click **Enforce** on Firestore /
   Storage after the metrics show your real traffic passing.

**Billing alert** (5 min, catches key abuse early): Cloud Console →
**Billing → Budgets & alerts → Create budget** → e.g. $25/month with email
alerts at 50/90/100%.

> When: App Check in the first weeks after launch (enforcing during review
> risks blocking Apple's test devices if misconfigured). The billing alert —
> today, it's free insurance.

---

## Sanity checklist when done

- [ ] Old `AIzaSyBW-` key deleted in Google Cloud
- [ ] New Places key restricted to Places API (New) only
- [ ] `PLACES_API_KEY` secure variable set in Codemagic
- [ ] Fresh Codemagic build → restaurant search in Create works
- [ ] Android Maps key: package + both SHA-1s, Maps SDK for Android only
- [ ] iOS Maps key: bundle id, Maps SDK for iOS only
- [ ] Nearby map still renders on a real build of each platform
- [ ] Billing budget alert created
