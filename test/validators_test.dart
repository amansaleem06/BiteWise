import 'package:bitewise/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final email in [
    'person@gmail.com',
    'person@outlook.com',
    'a@yahoo.com',
    'person@icloud.com',
    'first.last+food@my-restaurant.example',
    "o'connor@example.co.uk",
    ' person@example.com ',
  ]) {
    test('accepts $email', () => expect(Validators.email(email), isNull));
  }
  for (final email in [
    '',
    'person',
    'person@',
    '@example.com',
    'a@localhost',
    'a@.com',
    'a@domain..com',
    'a@@example.com',
    '.a@example.com',
    'a.@example.com',
    'a..b@example.com',
    'a b@example.com',
    'a@under_score.com',
    'a@-domain.com',
    'a@domain-.com',
    'a@example.123',
    'a\n@example.com',
    '${'a' * 65}@example.com',
    'a@${'b' * 64}.com',
  ]) {
    test(
      'rejects malformed email ${email.replaceAll('\n', r'\n')}',
      () => expect(Validators.email(email), isNotNull),
    );
  }
}
