import 'package:flutter_test/flutter_test.dart';
import 'package:nearkart/core/config/env_config.dart';

void main() {
  test('Google Sign-In has a Web client ID without a dart-define', () {
    expect(EnvConfig.googleServerClientId, isNotEmpty);
    expect(
      EnvConfig.googleServerClientId,
      contains('.apps.googleusercontent.com'),
    );
  });
}
