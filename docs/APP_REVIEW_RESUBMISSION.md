# TasteWise App Review resubmission

Use this checklist for the build that follows rejected build 38. Do not submit until every physical-device check below has passed.

## Release order

1. In Firebase Authentication, confirm Google is enabled for project `bitewise-1d266`.
2. Add Android signing fingerprints to the Firebase Android app `com.bitewise.bitewise`:
   - Debug SHA-1: `7E:93:DC:E9:54:62:4F:17:DD:8A:E3:A0:FA:33:B0:4F:1B:94:4A:80`.
   - Debug SHA-256 from `./gradlew signingReport`.
   - Google Play Console → Setup → App integrity: add both the Play App Signing SHA-1 and SHA-256.
3. Download the regenerated `google-services.json` and replace `android/app/google-services.json`. The checked-in file currently has no Android OAuth client/certificate entry, which prevents native Google sign-in from completing correctly.
4. Keep App Check in monitoring mode for this release. Do not enable enforcement until the released build has verified App Check traffic.
5. Build and deploy the Cloud Functions, including the public-profile projection and report resolver:

   ```sh
   npm --prefix functions run build
   firebase deploy --only functions --project bitewise-1d266
   ```

6. Create safe public projections for existing accounts. The first command is read-only and the second performs the writes. It uses Application Default Credentials and contains no embedded secret:

   ```sh
   npm --prefix functions run backfill:public-profiles -- --project bitewise-1d266
   npm --prefix functions run backfill:public-profiles -- --project bitewise-1d266 --apply
   ```

7. Deploy the tested Firestore rules after the backfill:

   ```sh
   firebase deploy --only firestore:rules --project bitewise-1d266
   ```

8. Publish the updated `docs/terms.html` page so the public EULA contains the same zero-tolerance language as the in-app document.
9. Produce a new Android build with `versionCode` 49 or greater. Produce the iOS archive through Codemagic for bundle ID `com.amansaleem06.bitewise`.

## App Store Connect metadata correction (Guideline 2.3.6)

TasteWise does not provide parental controls or age-assurance mechanisms. In App Store Connect, open the app’s App Information → Age Rating questionnaire and set both of these In-App Controls answers to **None**:

- Parental Controls: None
- Age Assurance: None

Save the questionnaire and verify the resulting age rating before resubmitting. This is a metadata correction; do not claim that these controls exist in Review Notes.

## Physical-device acceptance checks

- Fresh install: registration and every sign-in method show an unchecked Terms of Use / EULA checkbox with working Terms and Privacy links.
- Existing account: if the current terms version has not been accepted, the app opens the agreement gate before Feed or any user-generated content.
- Email signup: malformed addresses are rejected, a valid account receives a verification email, and the user cannot enter the main app until verification succeeds.
- Android Google sign-in: select a Google account that has never used TasteWise. It creates the Firebase Auth user and profile directly; cancellation returns cleanly; an account/provider conflict explains which existing method to use.
- Edit Profile: no phone field appears; bio saves and appears on the profile; choosing a photo opens a crop/reposition preview; Cancel leaves the old image unchanged; Save replaces it.
- Android Back: closes an open course menu, returns a secondary top-level tab to Feed, pops detail/settings screens, and exits only from root Feed.
- Reporting: report another user’s post, comment, story, profile, or conversation; confirm the success dialog and an `open` document in `reports`.
- Blocking: block from a post/profile/chat/story; confirm both users disappear from one another’s content and cannot follow, like, comment, message, or notify; verify Settings → Blocked accounts can unblock.
- Moderation: with a real `role: admin` account, open Profile → Settings → Moderation reports, add a required review note, then dismiss, hide, or suspend. Confirm the report closes and `moderationAudit` is written. For suspension, confirm Firebase Auth is disabled and existing sessions cannot participate.
- Run the scenario on the iPhone and iPad classes listed in the rejection, including an iPad layout pass.

## Screen recording requested by App Review

Record one continuous run on a physical iPhone or iPad:

1. Launch from a signed-out state.
2. Open Terms of Use / EULA and show the zero-tolerance clause.
3. Return, check the previously unchecked agreement box, and sign in with the review account.
4. Open another user’s post, tap `•••`, choose **Report post**, select a reason, and show **Report received**.
5. Open `•••` again, choose **Block user**, confirm, and show that the user’s content is removed.
6. Open Profile → Settings → Blocked accounts to show the persisted block and the Unblock control.

Attach the recording to the App Review message. Supply working review credentials in App Store Connect’s Sign-In Information; do not place credentials in source control or Review Notes.

## Paste-ready App Review Notes

> Guideline 1.2 — User-generated content precautions have been added and enforced. Before registration or sign-in, every authentication screen presents an unchecked “I agree to the Terms of Use / EULA” control with Terms and Privacy links. The EULA states zero tolerance for objectionable content and abusive behavior. Existing accounts that have not accepted the current terms version are gated before entering the app.
>
> A reviewer can report or block from another user’s post via the ••• menu. The same actions are available from user profiles, stories, and conversations; comments have a visible Report action, and the author’s profile provides Block. Reports are persisted for moderator review. Blocking is bilateral across feeds, profiles, stories, comments, search, notifications, and chat, and Settings → Blocked accounts provides unblock management. The attached physical-device recording demonstrates EULA acceptance, reporting, blocking, and unblock management.
>
> Guideline 2.3.6 — The Age Rating questionnaire has been corrected. “Parental Controls” and “Age Assurance” are both set to None because TasteWise does not provide or claim those mechanisms.
>
> Review account credentials are supplied in the App Review Sign-In Information field.

## Before pressing Submit for Review

- Confirm the uploaded build is newer than build 38 and Android `versionCode` is at least 49.
- Confirm the public Terms URL and Privacy URL load without authentication.
- Confirm the Firebase Functions and Firestore rules deployment timestamps match this release.
- Confirm the review account has accepted no cached agreement, so the reviewer can see the EULA flow, or explain exactly how to sign out/reset it.
- Attach the physical-device recording to the rejection reply.
- Paste the notes above, add the build, and answer the reviewer in App Store Connect.

References: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Firebase Google sign-in for Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth).
