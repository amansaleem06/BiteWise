/// Public URLs for App Store / Play Store legal disclosures.
///
/// Hosted via GitHub Pages from `/docs` (see NO_MAC_RELEASE.md).
abstract final class AppLegal {
  static const _pagesBase =
      'https://amansaleem06.github.io/BiteWise';

  static const privacyPolicyUrl = '$_pagesBase/privacy.html';
  static const termsOfServiceUrl = '$_pagesBase/terms.html';
  static const supportUrl = '$_pagesBase/support.html';

  static const privacyPolicyMarkdown = '''
# Privacy Policy

**Last updated:** August 10, 2026

TasteWise ("we", "our") helps you discover restaurants and share food experiences. This policy explains what we collect and why.

## Information we collect
- **Account data:** name, email, profile photo, bio.
- **Content you create:** posts, photos, comments, ratings, messages, and reservations.
- **Location:** when you allow it, to show nearby restaurants on the map.
- **Device data:** push notification tokens and basic diagnostics needed to run the app.

## How we use information
- Provide authentication, feeds, messaging, reservations, and notifications.
- Improve reliability and prevent abuse.
- Comply with law when required.

## Sharing
We use trusted processors such as Google Firebase (Auth, Firestore, Storage, Messaging) and Google Maps. We do not sell your personal information.

## Your choices
- Update or remove profile content in the app.
- Revoke location, camera, or notification permission in system settings.
- **Delete your account** anytime under Profile → Settings → Delete account. This removes your Auth account and personal profile data; shared posts are anonymized.

## Contact
Questions about privacy: privacy@tastewise.app
''';

  static const termsOfServiceMarkdown = '''
# Terms of Service

**Last updated:** August 10, 2026

By using TasteWise you agree to these terms.

## Eligibility
You must be able to form a binding contract in your country. If you are under 13 (or the digital-consent age where you live), you may not use the app.

## Your account
You are responsible for your login and for content you post. Do not share your password. You may delete your account at any time in Settings.

## Acceptable use
Do not post illegal, hateful, harassing, or infringing content. Do not spam, scrape, or attempt to disrupt TasteWise.

## Content license
You keep ownership of your content. You grant TasteWise a non-exclusive license to host and display it so the service can function. You can remove content or delete your account to stop ongoing display of personal profile data.

## Reservations & third parties
Restaurant availability and reservation outcomes depend on restaurant partners. Maps and location features depend on Google Maps / device location services.

## Disclaimers
TasteWise is provided “as is.” We do not guarantee uninterrupted service or the accuracy of user-generated restaurant content.

## Termination
We may suspend accounts that violate these terms. You may stop using TasteWise and delete your account at any time.

## Contact
legal@tastewise.app
''';
}
