import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';

import '../../loads/models/load_model.dart';
import '../cubit/customer_trucks_cubit.dart';
import '../models/customer_truck_model.dart';
import '../models/customer_trucks_screen_model.dart';

class CustomerTrucksScreen extends StatefulWidget {
  const CustomerTrucksScreen({super.key});

  @override
  State<CustomerTrucksScreen> createState() => _CustomerTrucksScreenState();
}

class _CustomerTrucksScreenState extends State<CustomerTrucksScreen> {
  final query = TextEditingController();
  String? selectedLoadId, vehicleType;
  double? minimumTonnes, latitude, longitude;
  double radiusKm = 50;
  String sort = 'nearest';

  static const _vehicleTypes = [
    'All Trucks',
    'Open truck',
    'Container',
    'Trailer',
    'Pickup',
    'LCV',
    'Mini truck',
    'Refrigerated',
  ];

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  bool _locating = false;

  bool get _isNearMeActive => latitude != null && selectedLoadId == null;

  bool get _hasActiveFilters =>
      vehicleType != null ||
      minimumTonnes != null ||
      radiusKm != 50 ||
      sort != 'nearest' ||
      selectedLoadId != null ||
      latitude != null ||
      query.text.isNotEmpty;

  void _clearFilters(CustomerTrucksScreenModel? model) {
    setState(() {
      query.clear();
      vehicleType = null;
      minimumTonnes = null;
      radiusKm = 50;
      sort = 'nearest';
      selectedLoadId = null;
      latitude = null;
      longitude = null;
    });
    context.read<CustomerTrucksCubit>().load(
      clearLoad: true,
      clearVehicleType: true,
      clearMinCapacity: true,
      clearLocation: true,
      radiusKm: 50,
      sort: 'nearest',
    );
  }

  Future<void> _search([CustomerTrucksScreenModel? model]) {
    final selectedLoad = _selectedLoad(model);
    final effLat = selectedLoad?.pickupLatitude ?? latitude;
    final effLng = selectedLoad?.pickupLongitude ?? longitude;
    return context.read<CustomerTrucksCubit>().load(
      query: query.text,
      loadId: selectedLoadId,
      vehicleType: vehicleType,
      minCapacityTonnes: minimumTonnes,
      latitude: effLat,
      longitude: effLng,
      radiusKm: radiusKm,
      sort: sort,
      clearLoad: selectedLoadId == null,
      clearVehicleType: vehicleType == null,
      clearMinCapacity: minimumTonnes == null,
      clearLocation: effLat == null && effLng == null,
    );
  }

  LoadModel? _selectedLoad(CustomerTrucksScreenModel? model) {
    if (selectedLoadId == null || model == null) return null;
    for (final load in model.openLoads) {
      if (load.id == selectedLoadId) return load;
    }
    return null;
  }

  Future<void> _findNearMe(CustomerTrucksScreenModel model) async {
    if (_isNearMeActive) {
      // Toggle off -> show all
      setState(() {
        latitude = null;
        longitude = null;
      });
      await context.read<CustomerTrucksCubit>().load(
        query: query.text,
        loadId: selectedLoadId,
        vehicleType: vehicleType,
        minCapacityTonnes: minimumTonnes,
        radiusKm: radiusKm,
        sort: sort,
        clearLocation: true,
      );
      if (mounted) {
        showNotice(context, 'Showing trucks across all regions.');
      }
      return;
    }

    setState(() => _locating = true);
    try {
      final location = await context
          .read<CustomerTrucksCubit>()
          .currentLocation();
      if (!mounted) return;
      if (!location.available) {
        showNotice(
          context,
          'Turn on GPS and allow location access to find trucks near you.',
        );
        return;
      }
      setState(() {
        selectedLoadId = null;
        latitude = location.latitude;
        longitude = location.longitude;
        sort = 'nearest';
      });
      await _search(model);
      if (mounted) {
        showNotice(
          context,
          'Showing trucks within ${radiusKm.toInt()} km of your current location.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _invite(
    CustomerTruckModel truck,
    List<LoadModel> loads, {
    LoadModel? selectedLoad,
  }) async {
    if (loads.isEmpty) {
      showNotice(context, 'Post an open load before inviting a truck.');
      return;
    }
    final load = selectedLoad ?? await _chooseLoad(truck, loads);
    if (load == null || !mounted) return;
    final cubit = context.read<CustomerTrucksCubit>();
    if (await cubit.invite(availabilityId: truck.id, loadId: load.id) &&
        mounted) {
      await _search(cubit.state.data);
    }
  }

  Future<LoadModel?> _chooseLoad(
    CustomerTruckModel truck,
    List<LoadModel> loads,
  ) => showModalBottomSheet<LoadModel>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF193F35).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF193F35),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite ${truck.driverName}',
                        style: Theme.of(sheet).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${truck.vehicleType} · ${truck.registrationLabel}',
                        style: Theme.of(sheet).textTheme.bodySmall?.copyWith(
                          color: Theme.of(sheet).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'SELECT AN OPEN SHIPMENT',
              style: Theme.of(sheet).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Theme.of(sheet).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheet).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: loads.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final load = loads[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(sheet).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(sheet).colorScheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: AppTheme.orange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${load.pickupLabel} → ${load.destinationLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${load.weightLabel} · ${load.cargo} · ${load.priceLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(sheet).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () => Navigator.pop(sheet, load),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _openFilterSheet(CustomerTrucksScreenModel model) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Available Trucks',
                      style: Theme.of(sheet).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_hasActiveFilters)
                      TextButton(
                        onPressed: () {
                          _clearFilters(model);
                          Navigator.pop(sheet);
                        },
                        child: const Text('Reset all'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'SEARCH RADIUS',
                  style: Theme.of(sheet).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [25, 50, 100, 250].map((r) {
                    final isSel = radiusKm == r;
                    return ChoiceChip(
                      label: Text('$r km'),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) {
                          setState(() => radiusKm = r.toDouble());
                          setSheetState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'MINIMUM PAYLOAD CAPACITY',
                  style: Theme.of(sheet).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    (null, 'Any'),
                    (2.0, '2+ tonnes'),
                    (5.0, '5+ tonnes'),
                    (10.0, '10+ tonnes'),
                    (20.0, '20+ tonnes'),
                  ].map((pair) {
                    final isSel = minimumTonnes == pair.$1;
                    return ChoiceChip(
                      label: Text(pair.$2),
                      selected: isSel,
                      onSelected: (val) {
                        setState(() => minimumTonnes = pair.$1);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'SORT RESULTS BY',
                  style: Theme.of(sheet).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ('nearest', 'Nearest distance'),
                    ('capacity_high', 'Highest capacity'),
                    ('capacity_low', 'Lowest capacity'),
                  ].map((pair) {
                    final isSel = sort == pair.$1;
                    return ChoiceChip(
                      label: Text(pair.$2),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) {
                          setState(() => sort = pair.$1);
                          setSheetState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Apply Filters',
                  icon: Icons.check,
                  onPressed: () {
                    Navigator.pop(sheet);
                    _search(model);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Available Trucks'),
      actions: [
        if (_hasActiveFilters)
          IconButton(
            tooltip: 'Clear filters',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: () => _clearFilters(
              context.read<CustomerTrucksCubit>().state.data,
            ),
          ),
      ],
    ),
    body: PageBody(
      narrow: true,
      onRefresh: () => _search(context.read<CustomerTrucksCubit>().state.data),
      child: BlocConsumer<CustomerTrucksCubit, ResourceState<CustomerTrucksScreenModel>>(
        listener: (context, state) {
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) => ResourceView<CustomerTrucksScreenModel>(
          state: state,
          retry: () => _search(state.data),
          builder: (model) {
            final selectedLoad = _selectedLoad(model);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Live Radar Discovery Hero
                _buildRadarHero(context, model, selectedLoad),
                const SizedBox(height: 18),

                // 2. Search & Filter Bar
                _buildSearchAndFiltersBar(context, model, selectedLoad),
                const SizedBox(height: 14),

                // 3. Vehicle Type Filter Chips
                _buildVehicleTypeChips(model),
                const SizedBox(height: 18),

                // 4. Results Header & Count
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.trucks.isEmpty
                                ? 'No trucks online'
                                : '${model.trucks.length} ${model.trucks.length == 1 ? 'truck' : 'trucks'} ready for dispatch',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            selectedLoad != null
                                ? 'Filtered for: ${selectedLoad.pickupLabel} → ${selectedLoad.destinationLabel}'
                                : (latitude != null
                                    ? 'Within ${radiusKm.toInt()} km of your GPS location'
                                    : 'Across all regions'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _openFilterSheet(model),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Filters'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Truck Cards or Empty State
                if (model.trucks.isEmpty)
                  AppEmptyState(
                    'No trucks match your criteria',
                    'Try expanding your search radius, selecting all vehicle types, or clearing filters.',
                    icon: Icons.local_shipping_outlined,
                    action: _hasActiveFilters
                        ? AppButton(
                            label: 'Reset search filters',
                            icon: Icons.replay_outlined,
                            onPressed: () => _clearFilters(model),
                          )
                        : null,
                  ),
                ...model.trucks.map(
                  (truck) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _TruckCard(
                      truck: truck,
                      selectedLoad: selectedLoad,
                      onInvite: () => _invite(
                        truck,
                        model.openLoads,
                        selectedLoad: selectedLoad,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  // ─── Radar Hero Banner ──────────────────────────────────────────────────────

  Widget _buildRadarHero(
    BuildContext context,
    CustomerTrucksScreenModel model,
    LoadModel? selectedLoad,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF13362D),
            Color(0xFF1B4337),
            Color(0xFF265A4B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13362D).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Decorative background graphics
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 15,
            bottom: 15,
            child: Icon(
              Icons.radar_rounded,
              size: 85,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5E9A9).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD5E9A9).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD5E9A9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE FLEET RADAR',
                      style: TextStyle(
                        color: Color(0xFFD5E9A9),
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Instant Truck Discovery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connect directly with verified transport operators who have posted availability near your pickup.',
                style: TextStyle(
                  color: Color(0xFFD1E4DA),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // Telemetry stats row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    _heroStat(
                      Icons.local_shipping_outlined,
                      '${model.trucks.length}',
                      'Active Trucks',
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    _heroStat(
                      Icons.inventory_2_outlined,
                      '${model.openLoads.length}',
                      'Your Open Loads',
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    _heroStat(
                      Icons.near_me_outlined,
                      '${radiusKm.toInt()} km',
                      'Radar Range',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dedicated Prominent Button: "Trucks Available Near Me"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _locating ? null : () => _findNearMe(model),
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF13362D),
                          ),
                        )
                      : Icon(
                          _isNearMeActive
                              ? Icons.my_location_rounded
                              : Icons.near_me_rounded,
                          size: 19,
                          color: const Color(0xFF13362D),
                        ),
                  label: Text(
                    _isNearMeActive
                        ? 'Trucks Near Me Active (GPS · ${radiusKm.toInt()} km)'
                        : 'Trucks Available Near Me',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: Color(0xFF13362D),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD5E9A9),
                    foregroundColor: const Color(0xFF13362D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFFD5E9A9), size: 16),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB4C8BF),
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ─── Search & Match Bar ─────────────────────────────────────────────────────

  Widget _buildSearchAndFiltersBar(
    BuildContext context,
    CustomerTrucksScreenModel model,
    LoadModel? selectedLoad,
  ) {
    return Column(
      children: [
        // Search Input Field
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: query,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _search(model),
                  decoration: const InputDecoration(
                    hintText: 'Search by driver, truck number, or city...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (query.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    query.clear();
                    _search(model);
                  },
                ),
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => _search(model),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Load Match & GPS Anchor Selector Row
        Row(
          children: [
            // Load match selector dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedLoadId,
                    isExpanded: true,
                    hint: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Match with open load',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All open loads (no filter)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...model.openLoads.map(
                        (l) => DropdownMenuItem<String?>(
                          value: l.id,
                          child: Text(
                            '${l.pickupLabel} → ${l.destinationLabel}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => selectedLoadId = val);
                      _search(model);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Location anchor button
            Tooltip(
              message: _isNearMeActive
                  ? 'Click to show all regions'
                  : 'Filter trucks near your GPS location',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                backgroundColor: _isNearMeActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                foregroundColor: _isNearMeActive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                side: BorderSide(
                  color: _isNearMeActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _locating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isNearMeActive ? Icons.my_location : Icons.near_me_outlined,
                      size: 17,
                    ),
              label: Text(
                _isNearMeActive ? 'Near Me' : 'Near Me',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _locating ? null : () => _findNearMe(model),
            ),
          ),
          ],
        ),
      ],
    );
  }

  // ─── Vehicle Type Filter Chips ──────────────────────────────────────────────

  Widget _buildVehicleTypeChips(CustomerTrucksScreenModel model) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _vehicleTypes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = _vehicleTypes[index];
          final isAll = type == 'All Trucks';
          final isSelected = isAll ? vehicleType == null : vehicleType == type;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            label: Text(type),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            onSelected: (val) {
              setState(() {
                vehicleType = isAll ? null : (val ? type : null);
              });
              _search(model);
            },
          );
        },
      ),
    );
  }
}

// ─── Modern Available Truck Card ─────────────────────────────────────────────

class _TruckCard extends StatelessWidget {
  const _TruckCard({
    required this.truck,
    required this.selectedLoad,
    required this.onInvite,
  });

  final CustomerTruckModel truck;
  final LoadModel? selectedLoad;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Driver info and License Plate Header
          Row(
            children: [
              // Driver Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF193F35), Color(0xFF2A5E4A)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD5E9A9).withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    truck.driverName.trim().isEmpty
                        ? 'D'
                        : truck.driverName.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Vehicle specs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            truck.driverName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${truck.vehicleType} • ${_feet(truck.lengthFt)} body',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // License plate
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF332F1A) : const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFBC02D).withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF57F17),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      truck.registrationLabel,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFFFFF176) : const Color(0xFF3E2723),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),

          // 2. Journey & Availability Route
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 15,
                    color: Color(0xFF2E7D32),
                  ),
                  if ((truck.preferredDestination ?? '').isNotEmpty) ...[
                    Container(
                      width: 1.5,
                      height: 20,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const Icon(
                      Icons.location_on,
                      size: 15,
                      color: Color(0xFFD5693C),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready at ${truck.location}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((truck.preferredDestination ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Heading to ${truck.preferredDestination}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Telemetry Specs Badges
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              _specBadge(
                context,
                Icons.scale_rounded,
                '${_tonnes(truck.capacityTonnes)} payload',
                const Color(0xFF193F35),
                const Color(0xFFE8F5E9),
              ),
              _specBadge(
                context,
                Icons.straighten_rounded,
                '${_feet(truck.lengthFt)} length',
                const Color(0xFF0D47A1),
                const Color(0xFFE3F2FD),
              ),
              if (truck.distanceKm != null)
                _specBadge(
                  context,
                  Icons.near_me_rounded,
                  '${truck.distanceKm!.toStringAsFixed(truck.distanceKm! < 10 ? 1 : 0)} km away',
                  const Color(0xFFE65100),
                  const Color(0xFFFFF3E0),
                ),
            ],
          ),

          // 4. Driver Note (if any)
          if (truck.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      truck.note,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Availability Schedule info
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Available ${DateFormat('d MMM, h:mm a').format(truck.availableFrom.toLocal())}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Primary Action Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF193F35),
                foregroundColor: const Color(0xFFD5E9A9),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onInvite,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                selectedLoad == null
                    ? 'Invite for a Load'
                    : 'Invite for this Load',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specBadge(
    BuildContext context,
    IconData icon,
    String text,
    Color darkColor,
    Color lightBg,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? darkColor.withValues(alpha: 0.25) : lightBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? darkColor.withValues(alpha: 0.45) : darkColor.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white70 : darkColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : darkColor,
            ),
          ),
        ],
      ),
    );
  }
}

String _tonnes(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} t';
String _feet(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} ft';
