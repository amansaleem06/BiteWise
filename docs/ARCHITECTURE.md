# BiteWise Architecture

This document explains how the codebase is organized so a new contributor can
find things, add a feature, and not break the conventions that keep the app
maintainable.

## Stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3, custom theme) |
| State management | Riverpod (`flutter_riverpod`, Notifier/AsyncNotifier) |
| Navigation | `go_router`, route table in `lib/app/router/` |
| Backend | Firebase: Auth, Firestore, Storage, Messaging, Cloud Functions |
| Server logic | TypeScript Cloud Functions in `functions/` |
| Maps / places | Google Maps SDK + Places API (New) |

## Top-level layout

```
BiteWise/
├── lib/                  # Flutter app code
│   ├── app/              # App shell: router, theme
│   ├── core/             # Shared, feature-agnostic code
│   └── features/         # One folder per product feature
├── functions/            # Cloud Functions (TypeScript)
├── firestore.rules       # Firestore security rules (deployed, not just docs)
├── storage.rules         # Storage security rules
├── firestore.indexes.json# Composite indexes
├── docs/                 # Documentation + legal pages
├── codemagic.yaml        # CI/CD (iOS + Android release builds)
└── SETUP.md              # Firebase / Google Cloud setup, milestone checklists
```

## `lib/` conventions

### `lib/app/`

Application-level wiring only. `router/` owns every route path and redirect
(auth guard lives here). `theme/` owns colors, typography, spacing. No feature
logic.

### `lib/core/`

Code that more than one feature uses and that knows nothing about any specific
feature:

- `config/` — build-time configuration (`MapsConfig` reads `--dart-define`).
- `constants/` — app-wide strings, cuisine list, legal texts.
- `errors/` — `AppException` and error-to-message mapping.
- `services/` — cross-feature services (media upload, location, places search,
  push notifications, restaurant page voice).
- `utils/` — pure helpers (formatters, validators, currency catalog).
- `widgets/` — shared UI atoms (buttons, text fields, snackbars).

If something is used by exactly one feature, it belongs in that feature, not
in core.

### `lib/features/<name>/`

Every feature follows the same three-layer split:

```
features/feed/
├── domain/
│   ├── entities/          # Plain Dart objects (Post, PostMedia). No Firebase imports.
│   └── repositories/      # Abstract interfaces (FeedRepository).
├── data/
│   ├── models/            # Firestore (de)serialization (PostModel.fromDoc).
│   └── repositories/      # Firestore/Storage implementations.
└── presentation/
    ├── providers/         # Riverpod controllers + providers.
    ├── screens/           # Full screens (routed).
    └── widgets/           # Feature-private widgets.
```

Rules of the split:

1. **domain** has no Firebase or Flutter imports. Entities are `Equatable`
   value objects.
2. **data** is the only layer that touches `cloud_firestore` /
   `firebase_storage`. It catches SDK exceptions and rethrows `AppException`
   so upper layers never depend on SDK types.
3. **presentation** talks to repositories through Riverpod providers, never
   directly to Firestore.
4. Features may import from `core/` and from other features' **domain**
   layers when unavoidable (e.g. restaurants ↔ feed share `Post`), but avoid
   importing another feature's data layer.

### State management pattern

Controllers are `Notifier`/`AsyncNotifier` subclasses exposed via providers:

- Read-only page data: `AsyncNotifierProvider` (`restaurantControllerProvider`).
- Mutations are optimistic where cheap (like/bookmark/follow): update state
  first, write, roll back on failure.
- After cross-feature writes, invalidate the affected providers
  (`ref.invalidate(...)`) rather than plumbing callbacks.

## Firestore data model (summary)

| Collection | Purpose |
|---|---|
| `users/{uid}` | Profile, role (`user` / `restaurantOwner`), counters |
| `users/{uid}/bookmarks,reposts,following,followers,tokens,notifications` | Per-user edges |
| `posts/{postId}` | All posts. `asRestaurantId` set ⇒ official page post; `restaurantId` set without it ⇒ diner mention |
| `posts/{postId}/likes,comments` | Post subcollections |
| `restaurants/{id}` | Restaurant page. `claimStatus`, `ownerId`, rating aggregates, `guestFeedMode` |
| `restaurants/{id}/followers` | Follow edges |
| `chats/{chatId}/messages` | DMs (chatId = sorted uid pair) |
| `reservations/{id}` | Booking requests |
| `stories/{id}` | 24h stories |

Denormalized counters (like counts, rating sums, follower counts) are
maintained by Cloud Functions in `functions/src/counters.ts`; the client also
bumps some counters optimistically where the rules allow exactly ±1.

## Security rules are code

`firestore.rules` and `storage.rules` are the actual backend authorization
layer — review them in every PR that changes reads/writes, and deploy with:

```bash
firebase deploy --only firestore:rules,storage
```

See `docs/SECURITY.md` for the threat model and key-handling policy.

## Adding a new feature — checklist

1. Create `lib/features/<name>/` with `domain/`, `data/`, `presentation/`.
2. Define entities + repository interface in domain.
3. Implement the repository against Firestore in data; map errors to
   `AppException`.
4. Expose a Riverpod controller in presentation/providers.
5. Add routes in `lib/app/router/`.
6. Update `firestore.rules` for any new collection — default is deny.
7. Add composite indexes to `firestore.indexes.json` if you query on multiple
   fields.
8. Run `flutter analyze` — zero issues is the bar.
9. Update this file's data-model table if you added a collection.

## Known debt / roadmap

- UI strings are partially centralized in `core/constants/app_strings.dart`;
  full localization (ARB + `flutter_localizations`) is future work.
- No widget/unit test suite yet — `test/` is the intended home.
- Consider Firebase App Check before significant scale (see SECURITY.md).
