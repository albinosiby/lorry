import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  const AppException(this.message);
  final String message;
  static AppException from(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) {
      if (error.code == 'invalid_credentials') {
        return const AppException('Email or password is incorrect.');
      }
      if (error.code == 'email_not_confirmed') {
        return const AppException(
          'Check your inbox and confirm your email first.',
        );
      }
      if (error.code == 'over_email_send_rate_limit') {
        return const AppException(
          'Please wait a moment before requesting another email.',
        );
      }
      return const AppException(
        'Authentication could not be completed. Check your details and try again.',
      );
    }
    if (error is PostgrestException &&
        ['23502', '23514', '22P02', '22003'].contains(error.code)) {
      return const AppException(
        'Some details are invalid. Check the form and try again.',
      );
    }
    if (error is PostgrestException && error.code == '23505') {
      return const AppException(
        'This action was already submitted. Refresh to see the latest status.',
      );
    }
    if (error is PostgrestException && error.code == '42501') {
      return const AppException(
        'Your account does not have permission for this action.',
      );
    }
    if (error is PostgrestException && error.code == 'P0001') {
      return AppException(error.message);
    }
    if (error is StorageException) {
      return AppException(
        error.message.isEmpty
            ? 'Document upload failed. Please try again.'
            : error.message,
      );
    }
    if (error is FunctionException) {
      final details = error.details;
      final functionMessage = details is Map && details['error'] is String
          ? details['error'] as String
          : null;
      if (error.status == 0) {
        return const AppException(
          'Unable to connect. Check your connection and try again.',
        );
      }
      if (functionMessage != null && functionMessage.isNotEmpty) {
        return AppException(functionMessage);
      }
      if (error.status == 401) {
        return const AppException('Please sign in again to use this service.');
      }
      return const AppException(
        'This service is temporarily unavailable. Please try again.',
      );
    }
    return const AppException(
      'Unable to connect. Check your connection and try again.',
    );
  }

  @override
  String toString() => message;
}
