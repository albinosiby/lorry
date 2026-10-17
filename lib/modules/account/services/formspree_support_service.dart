import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../../utils/exceptions/app_exception.dart';
import '../models/support_request.dart';

/// Sends customer support requests to the Formspree form configured for the
/// app. Formspree owns the destination email; no mail credentials are stored
/// in the mobile application.
class FormspreeSupportService {
  FormspreeSupportService({http.Client? client, String? formId})
    : _client = client,
      _formId = formId ?? AppConfig.formspreeFormId;

  final http.Client? _client;
  final String _formId;

  Future<void> submit(SupportRequest request) async {
    if (_formId.trim().isEmpty) {
      throw const AppException(
        'Support is not configured yet. Please contact the support team directly.',
      );
    }

    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.https('formspree.io', '/f/${_formId.trim()}'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': request.name.trim(),
              'email': request.email.trim(),
              'issue': request.issue.trim(),
              'user_id': request.userId,
              'user_role': request.userRole,
              'phone': request.phone,
              '_subject': 'Lorry Link support request',
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AppException(
          'Unable to send your support request. Please try again.',
        );
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Unable to connect. Check your connection and try again.',
      );
    } finally {
      if (ownsClient) client.close();
    }
  }
}
