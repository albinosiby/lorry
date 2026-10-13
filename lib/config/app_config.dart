import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const googleEnabled = bool.fromEnvironment('GOOGLE_SIGN_IN_ENABLED');
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get configured =>
      Uri.tryParse(url)?.hasScheme == true &&
      key.isNotEmpty &&
      !url.contains('YOUR_PROJECT') &&
      !key.startsWith('YOUR_');
  static String get redirectUrl => kIsWeb
      ? '${Uri.base.origin}/auth/callback'
      : 'com.lorrylink.app://login-callback/';
}
