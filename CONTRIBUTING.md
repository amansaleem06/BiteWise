# Contributing to TasteWise

## Getting set up

1. Install Flutter (stable channel) and run `flutter doctor`.
2. `flutter pub get`
3. Run the app:

```bash
flutter run --dart-define=PLACES_API_KEY=<your-dev-places-key>
```

The app runs without the key too — Maps restaurant search degrades to manual
entry. Firebase needs no local secrets; client configs are committed.

Read `docs/ARCHITECTURE.md` before your first change and `docs/SECURITY.md`
before touching rules, uploads, or anything involving keys.

## Project conventions

- **Feature-first structure.** New code goes in
  `lib/features/<feature>/{domain,data,presentation}`. Shared code goes in
  `lib/core/` only when 2+ features need it.
- **No Firebase types outside `data/`.** Repositories catch SDK errors and
  rethrow `AppException`.
- **Riverpod for all state.** No `setState` for anything that outlives a
  widget; no global singletons for app state.
- **No hardcoded config.** API keys via `--dart-define`; user-facing strings
  in `core/constants/app_strings.dart` (or the feature) rather than scattered
  literals; magic numbers get a named constant.
- **Comments explain *why*,** not what the next line does.

## Quality bar for every PR

1. `flutter analyze` — zero errors, zero warnings, zero infos.
2. If you changed Firestore access patterns, update `firestore.rules` and
   `firestore.indexes.json` in the same PR, and note that rules must be
   deployed.
3. If you added a collection or field, update the data-model table in
   `docs/ARCHITECTURE.md`.
4. Test on at least one platform with a **second, non-owner account** for any
   permission-sensitive change.
5. Commit messages: one sentence, imperative, describing the user-visible
   outcome (see `git log` for the style).

## What never gets merged

- Secrets, keys, keystores, service-account files — in any file, even
  "temporarily". If it happened, rotate the credential.
- Client-side authorization as the only protection for a write.
- Direct Firestore access from widgets.
- New rules that widen access without a comment explaining why.

## Release

CI is Codemagic (`codemagic.yaml`): iOS → TestFlight, Android → AAB. Secure
variables (`PLACES_API_KEY`, signing) are configured in the Codemagic UI,
never in the repo. See `NO_MAC_RELEASE.md` for the full iOS pipeline.
