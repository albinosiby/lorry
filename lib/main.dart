import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'di/injection.dart';
import 'utils/services/secure_session_storage.dart';
import 'utils/services/notification_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  if (!AppConfig.configured) {
    runApp(const SetupApp());
    return;
  }
  try {
    await Supabase.initialize(
      url: AppConfig.url,
      publishableKey: AppConfig.key,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: kIsWeb ? null : const SecureSessionStorage(),
      ),
    );
    configureDependencies(Supabase.instance.client);
    await NotificationSyncService.initializeFirebase();
    runApp(const LorryLinkApp());
  } catch (_) {
    runApp(
      const SetupApp(
        error:
            'Could not initialize the app. Check the Supabase URL and publishable key, then restart.',
      ),
    );
  }
}
