import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../../loads/models/load_model.dart';
import '../../loads/widgets/load_card.dart';
import '../cubit/trips_cubit.dart';
import '../models/booking_screen_models.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, this.loadId, this.requests = false});
  final String? loadId;
  final bool requests;
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String? status;
  @override
  void initState() {
    super.initState();
    status = widget.requests ? 'requested' : null;
  }

  Future<void> refresh() =>
      context.read<TripsCubit>().load(loadId: widget.loadId, status: status);
  @override
  Widget build(BuildContext context) {
    final body = PageBody(
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            widget.requests ? 'Choose your connection' : 'Your journeys',
            widget.requests ? 'Booking requests' : 'My trips',
            widget.requests
                ? 'Review drivers and choose the right fit for your load.'
                : 'From first request to final delivery.',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                        null,
                        'requested',
                        'accepted',
                        'in_transit',
                        'completed',
                        'declined',
                        'cancelled',
                      ]
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s == null ? 'All' : statusLabel(s)),
                            selected: status == s,
                            onSelected: (_) {
                              setState(() => status = s);
                              refresh();
                            },
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<TripsCubit, ResourceState<TripsScreenModel>>(
            builder: (context, state) => ResourceView<TripsScreenModel>(
              state: state,
              retry: refresh,
              builder: (model) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (model.bookings.isEmpty)
                    AppEmptyState(
                      widget.requests
                          ? 'No requests here'
                          : 'No trips here yet',
                      widget.requests
                          ? 'Incoming requests will appear when drivers find your loads.'
                          : 'Find an available load and send your first request.',
                      icon: Icons.route_outlined,
                    ),
                  ...model.bookings.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await context.push('/bookings/${b.id}');
                            if (mounted) refresh();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.requests
                                            ? b.driverName
                                            : b.load.vehicle,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    StatusBadge(
                                      b.deliveryReportedAt != null &&
                                              b.status == 'in_transit'
                                          ? 'Delivery reported'
                                          : statusLabel(b.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                RouteSummary(b.load.pickup, b.load.destination),
                                const Divider(),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text(b.load.dateLabel),
                                    Text(
                                      b.load.priceLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (model.hasMore)
                    OutlinedButton(
                      onPressed: state.loading
                          ? null
                          : () => context.read<TripsCubit>().more(),
                      child: const Text('Load more'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return widget.requests
        ? Scaffold(
            appBar: AppBar(title: const Text('Booking requests')),
            body: body,
          )
        : body;
  }
}
