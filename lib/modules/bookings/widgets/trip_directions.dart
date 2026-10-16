import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../utils/services/map_navigation_service.dart';
import '../models/booking_model.dart';

/// Shared by Home and live tracking so both open the same ordered route.
Future<void> openTripDirections(
  BuildContext context,
  BookingModel booking,
) async {
  final service = MapNavigationService();
  final plan = service.tripPlan(booking);
  if (plan.deferredStops > 0) {
    if (!await confirmAction(
      context,
      'Navigate this route section?',
      'This section visits the next unloading stops and ends at ${plan.endLabel}. '
          '${plan.deferredStops} later destination(s), including final delivery, remain. '
          'Mark each completed stop Unloaded in Booking details, then reopen directions '
          'to continue. Google Maps does not mark unloading in this app.',
      confirm: 'Open Google Maps',
    )) {
      return;
    }
    if (!context.mounted) return;
  }
  final opened = await service.openPlan(plan);
  if (context.mounted && !opened) {
    showNotice(context, 'Could not open Google Maps. Please try again.');
  }
}
