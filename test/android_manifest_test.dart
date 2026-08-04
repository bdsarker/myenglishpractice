import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the one bug class that every other check in this repo is blind to.
///
/// Flutter's template declares `INTERNET` in `src/debug` and `src/profile` only,
/// so a release build silently loses network access while `flutter analyze`,
/// the whole test suite and any `flutter run` keep passing. The first symptom is
/// a shipped APK where every lookup fails.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('the main manifest declares INTERNET, so release builds have network', () {
    expect(manifest.existsSync(), isTrue,
        reason: 'run from the project root');

    expect(
      manifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
      reason: 'Release builds do not inherit src/debug/AndroidManifest.xml. '
          'Without this line every HTTPS call fails with Permission denied.',
    );
  });
}
