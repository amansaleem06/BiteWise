# TasteWise App Review checklist

Use this checklist for the first App Store submission and every major update.
The App Store product name can change to TasteWise without changing the
existing bundle ID (`com.amansaleem06.bitewise`).

## Before uploading

- [ ] Replace and test the expired Android Maps key (does not block iOS).
- [ ] Keep Firebase App Check in monitor mode until verified TestFlight traffic
  appears; do not enforce it immediately before review.
- [ ] Deploy Firestore rules so report/block writes are allowed:
  `firebase deploy --only firestore:rules`
- [ ] Deploy Cloud Functions if push titles should say TasteWise:
  `firebase deploy --only functions:onNotificationPush`
- [ ] Run `flutter analyze` and the Flutter test suite.
- [ ] Test a release build on a physical iPhone:
  - Email sign-up, verification, sign-in, sign-out, and password reset
  - Sign in with Apple and Google
  - Account deletion, including recent-login reauthentication
  - Create/delete a post, camera/photo access, comments, and messages
  - Report a post and block a user from a profile and a chat
  - Nearby restaurants with location denied, allowed, and disabled
  - Dark, light, and system appearance
  - Restaurant search using the release `PLACES_API_KEY`
  - Push notifications
- [ ] Confirm the version and build number are higher than the latest uploaded
  build.

## User-generated content requirement

TasteWise contains posts, comments, profiles, and direct messages. Apple
Guideline 1.2 is covered in-app:

- Report a post from the post overflow menu
- Report or block a user from their profile or a chat
- Blocked users are hidden from the feed and message list
- Support contact: `https://amansaleem06.github.io/BiteWise/support.html`
- Terms prohibit abusive content

Review reports in Firebase Console → Firestore → `reports`. Respond from
the published support email.

## App Store Connect

### App information

- **Name:** `TasteWise: Discover & Share`
- **Subtitle:** `Discover. Taste. Share.`
- **Primary category:** Food & Drink
- **Secondary category:** Social Networking
- Keep the existing bundle ID: `com.amansaleem06.bitewise`
- Paste the description and keywords from `docs/APP_STORE_LISTING.md`.

Changing the App Store name is done in App Store Connect under the app
version's localized **App Information**. The name in the binary has already
been changed through `CFBundleDisplayName`.

### URLs

- Privacy Policy:
  `https://amansaleem06.github.io/BiteWise/privacy.html`
- Support:
  `https://amansaleem06.github.io/BiteWise/support.html`
- Marketing:
  `https://amansaleem06.github.io/BiteWise/`

The GitHub repository path may remain `BiteWise`; changing it is unnecessary
for the customer-facing rename and could break existing links.

### App Privacy

Answer from actual production behavior. At minimum review declarations for:

- Contact information: name and email address
- Precise location
- User content: photos/videos, audio, messages, and other user content
- Identifiers: user ID
- Diagnostics collected by Firebase or other included SDKs

Declare data as linked to the user where it is stored against their account.
Do not mark data as used for tracking unless it is combined across companies'
apps or websites for advertising or data-broker purposes.

### Age rating and content rights

- Declare user-generated content and messaging/social features.
- Restaurant content may contain alcohol references; answer the questionnaire
  according to the content actually allowed.
- Confirm that TasteWise has rights to every screenshot, icon, photo, and
  promotional asset submitted.

### Screenshots

Upload current screenshots that show the production UI and TasteWise branding.
At minimum prepare the required iPhone size shown by App Store Connect; add
iPad screenshots only if the submitted build supports iPad.

Do not place prices, unsupported claims, Android UI, device frames that obscure
the app, or references to competing stores in screenshots.

## Review information

- Provide a stable demo account with representative content.
- Do not require the reviewer to create a restaurant or wait for email
  verification to inspect core functionality.
- Add concise instructions for the demo account, restaurant-owner features,
  location permission, post creation, messaging, and account deletion.
- Mention that location is used only to show nearby restaurants.
- Provide a monitored contact name, phone number, and email address.

Suggested review note:

> TasteWise is a social food-discovery app. Use the supplied demo account to
> view the feed, nearby restaurants, messaging, and restaurant-owner features.
> Location is requested only when opening nearby discovery. Account deletion is
> available at Profile → Settings → Delete account. Sign in with Apple is
> available on iOS.

## Submission

1. Upload a fresh build to TestFlight.
2. Complete export compliance, content rights, age rating, App Privacy, and
   review-contact sections.
3. Attach the selected build and allow processing to finish.
4. Complete a final TestFlight smoke test.
5. Submit manually in App Store Connect. Keep Codemagic's
   `submit_to_app_store` disabled until this checklist is complete.
