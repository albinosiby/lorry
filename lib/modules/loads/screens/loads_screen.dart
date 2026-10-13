import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../cubit/loads_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../widgets/load_card.dart';

class LoadsScreen extends StatefulWidget {
  const LoadsScreen({super.key, this.mine = false});
  final bool mine;
  @override
  State<LoadsScreen> createState() => _LoadsScreenState();
}

class _LoadsScreenState extends State<LoadsScreen> {
  LoadFilter filter = const LoadFilter();
  Future<void> refresh() =>
      context.read<LoadsCubit>().load(mine: widget.mine, filter: filter);
  Future<void> filters() async {
    var pickup = filter.pickup,
        destination = filter.destination,
        vehicle = filter.vehicle;
    final pickupText = TextEditingController(text: pickup);
    final destinationText = TextEditingController(text: destination);
    final result = await showModalBottomSheet<LoadFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Find your next load',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a pickup near your last delivery to find a return load.',
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: pickupText,
                  label: 'Pickup place',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) =>
                      pickup = v.trim().isEmpty ? null : placeLabel(v),
                ),
                AppTextField(
                  controller: destinationText,
                  label: 'Destination place',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) =>
                      destination = v.trim().isEmpty ? null : placeLabel(v),
                ),
                _filterDrop(
                  'Vehicle type',
                  vehicleTypes,
                  vehicle,
                  (v) => set(() => vehicle = v),
                ),
                AppButton(
                  label: 'Show matching loads',
                  onPressed: () => Navigator.pop(
                    ctx,
                    LoadFilter(
                      pickup: pickup,
                      destination: destination,
                      vehicle: vehicle,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, const LoadFilter()),
                  child: const Text('Clear all filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    pickupText.dispose();
    destinationText.dispose();
    if (result != null && mounted) {
      setState(() => filter = result);
      await refresh();
    }
  }

  Widget _filterDrop(
    String label,
    List<String> values,
    String? value,
    ValueChanged<String?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('Any')),
        ...values.map((v) => DropdownMenuItem(value: v, child: Text(v))),
      ],
      onChanged: change,
    ),
  );
  @override
  Widget build(BuildContext context) => PageBody(
    onRefresh: refresh,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          widget.mine ? 'Your shipments' : 'Load marketplace',
          widget.mine ? 'My loads' : 'Find your next load',
          widget.mine
              ? 'Every listing, every request, in one place.'
              : 'A better route starts with the right connection.',
        ),
        if (widget.mine) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      null,
                      'open',
                      'assigned',
                      'in_transit',
                      'completed',
                      'cancelled',
                    ]
                    .map(
                      (status) => ChoiceChip(
                        label: Text(
                          status == null ? 'All' : statusLabel(status),
                        ),
                        selected: filter.status == status,
                        onSelected: (_) {
                          setState(() => filter = LoadFilter(status: status));
                          refresh();
                        },
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/requests'),
            icon: const Icon(Icons.pending_actions_outlined),
            label: const Text('View all booking requests'),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                        filter.pickup,
                        filter.destination,
                        filter.vehicle,
                      ].whereType<String>().join(' · ').isEmpty
                      ? 'All routes · All vehicles'
                      : [
                          filter.pickup,
                          filter.destination,
                          filter.vehicle,
                        ].whereType<String>().join(' · '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: filters,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filters'),
              ),
            ],
          ),
        const SizedBox(height: 22),
        BlocBuilder<LoadsCubit, ResourceState<LoadsScreenModel>>(
          builder: (context, state) => ResourceView<LoadsScreenModel>(
            state: state,
            retry: refresh,
            builder: (model) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (model.loads.isEmpty)
                  AppEmptyState(
                    widget.mine ? 'No loads here yet' : 'No matching loads',
                    widget.mine
                        ? 'Post a load and connect with transporters.'
                        : 'Try a different city or vehicle type.',
                    icon: Icons.local_shipping_outlined,
                    action: OutlinedButton(
                      onPressed: widget.mine
                          ? () => context.go('/loads/new')
                          : () {
                              setState(() => filter = const LoadFilter());
                              refresh();
                            },
                      child: Text(
                        widget.mine ? 'Post a load' : 'Clear filters',
                      ),
                    ),
                  )
                else
                  LoadGrid(
                    loads: model.loads,
                    showRequests: widget.mine,
                    onTap: (load) async {
                      await context.push('/loads/${load.id}');
                      if (mounted) await refresh();
                    },
                  ),
                if (model.hasMore) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: state.loading
                        ? null
                        : () => context.read<LoadsCubit>().more(),
                    child: const Text('Load more'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
