import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../vehicles/models/vehicle_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/booking_details_cubit.dart';
import '../../../design_system/design_system.dart';

Future<bool> ensureBookingTruck(BuildContext context, String id) async {
  final cubit = context.read<BookingDetailsCubit>();
  await cubit.load(id);
  final booking = cubit.state.data?.booking;
  if (booking == null) return false;
  if (booking.vehicleId != null) return true;
  try {
    final trucks = await cubit.matchingTrucks(booking.load);
    if (!context.mounted) return false;
    final selected = await chooseBookingTruck(context, trucks);
    if (selected == null) return false;
    return await cubit.assignTruck(id, selected.id);
  } catch (_) {
    if (context.mounted) {
      showNotice(context, 'Could not load your trucks. Try again.');
    }
    return false;
  }
}

Future<VehicleModel?> chooseBookingTruck(
  BuildContext context,
  List<VehicleModel> trucks,
) => showModalBottomSheet<VehicleModel>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedText(
              'Select truck for this load',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (trucks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LocalizedText(
                  'No suitable trucks. Add a truck matching the load type, tonnes and length in Manage my trucks.',
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final truck in trucks)
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(truck.registrationNumber),
                      subtitle: LocalizedText(
                        '${localize(context, truck.vehicleType)} · ${truck.capacityTonnes} t · ${truck.lengthFt} ft',
                      ),
                      onTap: () => Navigator.pop(context, truck),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
