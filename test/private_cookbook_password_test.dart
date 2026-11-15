import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_haven/services/private_cookbook_password.dart';

void main() {
  test('private cookbook password uses a salted verifier, never plain text', () async {
    final salt = List<int>.generate(24, (i) => i + 1);
    final stored = await PrivateCookbookPassword.buildVerifier(
      'My Safe Password 123!', salt: salt,
    );
    expect(stored, startsWith('v1:'));
    expect(stored, isNot(contains('My Safe Password 123!')));
    expect(await PrivateCookbookPassword.verifyVerifier(
      stored, 'My Safe Password 123!',
    ), isTrue);
    expect(await PrivateCookbookPassword.verifyVerifier(
      stored, 'incorrect password',
    ), isFalse);
  });

  test('rejects short passwords and malformed verifiers', () async {
    expect(
      () => PrivateCookbookPassword.buildVerifier('short'),
      throwsA(isA<FormatException>()),
    );
    expect(await PrivateCookbookPassword.verifyVerifier(
      'v1:malformed:hash', 'anything longer',
    ), isFalse);
  });
}
