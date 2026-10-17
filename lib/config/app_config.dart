import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const androidApplicationId = 'com.newlorrylink.app';
  static const googleEnabled = bool.fromEnvironment('GOOGLE_SIGN_IN_ENABLED');
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Public Formspree form ID. The recipient email is configured in Formspree,
  /// not embedded in the Android app.
  static const formspreeFormId = String.fromEnvironment('FORMSPREE_FORM_ID');

  /// OSM-compatible tile template. A hosted provider can be supplied for
  /// production builds with `--dart-define=OSM_TILE_URL=...`.
  static const mapTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static bool get hasMapTiles =>
      mapTileUrl.contains('{z}') && mapTileUrl.contains('{x}');
  static bool get configured =>
      Uri.tryParse(url)?.hasScheme == true &&
      key.isNotEmpty &&
      !url.contains('YOUR_PROJECT') &&
      !key.startsWith('YOUR_');
  static String get redirectUrl => kIsWeb
      ? '${Uri.base.origin}/auth/callback'
      : defaultTargetPlatform == TargetPlatform.android
      ? '$androidApplicationId://login-callback/'
      : 'com.lorrylink.app://login-callback/';
}
