import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/config/app_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android app ID and login callback agree with build and manifest', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppConfig.androidApplicationId, 'com.newlorrylink.app');
    expect(AppConfig.redirectUrl, 'com.newlorrylink.app://login-callback/');
    expect(
      File('android/app/build.gradle.kts').readAsStringSync(),
      contains('applicationId = "${AppConfig.androidApplicationId}"'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:scheme="${AppConfig.androidApplicationId}"'),
    );
  });

  test('Android rename does not change the existing iOS callback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppConfig.redirectUrl, 'com.lorrylink.app://login-callback/');
  });
  test(
    'Firebase configuration includes the renamed Android app in the same project',
    () {
      final config =
          jsonDecode(
                File('android/app/google-services.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(config['project_info']['project_id'], 'lorry-link-e2906');
      expect(
        (config['client'] as List).any(
          (client) =>
              client['client_info']['android_client_info']['package_name'] ==
              AppConfig.androidApplicationId,
        ),
        isTrue,
      );
    },
  );
}
