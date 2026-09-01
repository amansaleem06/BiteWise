# TasteWise Security

How the app protects user data, what is intentionally public, and what every
contributor must never do.

## Threat model in one paragraph

The Flutter app is untrusted code running on user devices. Anything shipped in
the binary (Dart strings, plist/manifest values) can be extracted. Therefore
**authorization lives server-side** in Firestore/Storage security rules and
Cloud Functions — never in the client. Client checks exist only for UX.

## Secrets policy

| Value | Where it lives | Why |
|---|---|---|
| Firebase API keys (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`) | Committed | These are identifiers, not secrets ([Firebase docs](https://firebase.google.com/docs/projects/api-keys)). Data access is gated by security rules + Auth. |
| Maps SDK keys (`AndroidManifest.xml`, `AppDelegate.swift`) | Committed, **restricted** | Must be locked in Google Cloud to the Android package + SHA-1 and the iOS bundle id. Restricted keys are useless outside our binaries. |
| Places REST key | `--dart-define=PLACES_API_KEY` only | REST keys can't be app-restricted the same way, so it never enters source control. CI injects it from a secure variable. |
| Signing keystores, App Store Connect keys, service-account JSON | Never in the repo (`.gitignore` blocks them) | Real secrets. Codemagic holds them as encrypted integrations/variables. |

**Rules for contributors**

1. Never commit a key, token, password, or service-account file. `.gitignore`
   helps, but treat it as a last line of defense, not permission.
2. New third-party API? The key goes through `--dart-define` (see
   `lib/core/config/maps_config.dart` as the template) or, better, behind a
   Cloud Function so the key stays server-side.
3. If a secret ever lands in git history, **rotate it** — deleting the commit
   is not enough.

## Backend authorization

### Firestore (`firestore.rules`)

- Default deny: the final `match /{document=**}` blocks anything not
  explicitly allowed.
- Users can only write their own profile, and can never change `role` or
  counters.
- Posts: author-only updates/deletes (plus page owner for official page
  posts); counter fields may only move by exactly ±1 with no other changes.
- Restaurant claims: only `restaurantOwner` accounts, only unclaimed
  listings, and rating aggregates/name are locked during a claim.
- Mentions moderation: the tagged restaurant's owner may flip only
  `mentionApproved` / `mentionHidden` on diner posts.
- Chats: participants only; the participant list is immutable; messages are
  immutable.

### Storage (`storage.rules`)

Per-path owner checks (`request.auth.uid == uid` in the path), content-type
must be image/audio, size caps (2–5 MB). Default deny at the bottom.

### Cloud Functions (`functions/`)

Trusted environment. Counter maintenance, push fan-out, trending scores, and
account-deletion cascade run here with admin credentials. Anything the client
must not be able to fake (aggregates, deletion cleanup) belongs here.

### Deploying rules

Rules are live config, not documentation:

```bash
firebase deploy --only firestore:rules,storage
```

## Client-side practices

- EXIF/GPS metadata is stripped from uploaded photos
  (`MediaUploadService._compress`, `keepExif: false`).
- Location is optional everywhere; denial is a normal state
  (`LocationService` never throws).
- Firebase Auth handles credentials; the app never stores passwords.
- Account deletion (App Store Guideline 5.1.1) is self-serve in Settings and
  cascades server-side (`onAuthUserDeleted`).

## Pre-launch checklist

- [ ] Maps SDK Android key restricted to package `com.bitewise.bitewise` +
      release SHA-1 (and debug SHA-1 for dev) in Google Cloud.
- [ ] Maps SDK iOS key restricted to bundle `com.amansaleem06.bitewise`.
- [ ] Places REST key restricted to *Places API (New)* only, injected via
      `--dart-define`, **rotated if it was ever committed**.
- [ ] `firebase deploy --only firestore:rules,storage` run after any rules
      change.
- [ ] Codemagic secure variables set: `PLACES_API_KEY`; signing via
      integrations, not files in the repo.
- [ ] Test with a second (non-owner) account: cannot edit someone else's
      post/profile/restaurant, cannot read others' chats.

## Recommended next steps (post-launch)

1. **Firebase App Check** (Play Integrity / App Attest) so only genuine app
   builds can call Firebase — the biggest single upgrade available.
2. **Budget alerts** in Google Cloud Billing to catch API abuse early.
3. **Crashlytics** for crash triage.
4. Move Places search behind a callable Cloud Function so no Places key ships
   in the binary at all.

## Reporting

Found a vulnerability? Do not open a public issue — email the maintainer
directly (see App Store support contact).
