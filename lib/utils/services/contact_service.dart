import 'package:url_launcher/url_launcher.dart';
import '../exceptions/app_exception.dart';

class ContactService {
  Future<void> call(String phone) async {
    final safe = phone.replaceAll(RegExp(r'[^+0-9]'), '');
    if (safe.isEmpty || !await launchUrl(Uri(scheme: 'tel', path: safe))) {
      throw const AppException(
        'Could not open your phone app. You can copy the number instead.',
      );
    }
  }
}
