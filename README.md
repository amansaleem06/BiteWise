# TasteWise

Discover. Taste. Share. — a food-focused social app built with Flutter +
Firebase. Diners share plates, rate dishes, and book tables; restaurant owners
claim a page, post as the business, and moderate diner mentions.

## Quick start

```bash
flutter pub get
flutter run --dart-define=PLACES_API_KEY=<optional-places-key>
```

Without the key the app still runs; Google-Maps restaurant search falls back
to manual restaurant entry. Firebase client configs are committed — no local
secrets needed.

## Documentation

| Doc | What's in it |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Folder structure, layering rules, data model, how to add a feature |
| [docs/SECURITY.md](docs/SECURITY.md) | Threat model, secrets policy, rules, pre-launch checklist |
| [docs/KEY_SETUP_GUIDE.md](docs/KEY_SETUP_GUIDE.md) | Click-by-click guide: rotate/restrict Google keys, Codemagic variable, App Check |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Conventions and the PR quality bar |
| [SETUP.md](SETUP.md) | Firebase / Google Cloud console setup, milestone history |
| [NO_MAC_RELEASE.md](NO_MAC_RELEASE.md) | Ship to the App Store without a Mac (Codemagic + TestFlight) |
| [docs/APP_STORE_LISTING.md](docs/APP_STORE_LISTING.md) | Store listing copy |
| [docs/APP_REVIEW_CHECKLIST.md](docs/APP_REVIEW_CHECKLIST.md) | Release testing, App Store Connect, privacy, and review checklist |

## Stack

Flutter (Material 3) · Riverpod · go_router · Firebase (Auth, Firestore,
Storage, Messaging, Cloud Functions in TypeScript) · Google Maps + Places API.

## Repository map

```
lib/app/        router + theme
lib/core/       shared config, services, utils, widgets
lib/features/   feature modules (domain / data / presentation)
functions/      Cloud Functions (counters, push, trending, deletion cascade)
firestore.rules, storage.rules   backend authorization — deploy on change:
                firebase deploy --only firestore:rules,storage
```

## Legal

- [Privacy Policy](docs/privacy.html)
- [Terms of Service](docs/terms.html)
