import 'dart:async';
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
  final search = TextEditingController();
  String searchQuery = '';
  Timer? activeLoadsRefresh;

  @override
  void initState() {
    super.initState();
    if (widget.mine) {
      activeLoadsRefresh = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) refresh();
      });
    }
  }

  @override
  void dispose() {
    activeLoadsRefresh?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() =>
      context.read<LoadsCubit>().load(mine: widget.mine, filter: filter);

  Future<void> openFilters() async {
    final result = await showModalBottomSheet<LoadFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LoadFiltersSheet(filter: filter),
    );
    if (result != null && mounted) {
      setState(() => filter = result);
      await refresh();
    }
  }

  int get _activeFilterCount {
    var count = 0;
    if (filter.pickup != null && filter.pickup!.isNotEmpty) count++;
    if (filter.destination != null && filter.destination!.isNotEmpty) count++;
    if (filter.vehicle != null && filter.vehicle!.isNotEmpty) count++;
    if (filter.maxWeightTonnes != null) count++;
    if (filter.minVehicleLengthFt != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PageBody(
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.mine)
            _buildShipperHeader(context, isDark)
          else
            _buildDriverMarketplaceBanner(context, isDark),
          const SizedBox(height: 18),
          if (widget.mine) ...[
            OutlinedButton.icon(
              onPressed: () => context.push('/loads/new'),
              icon: const Icon(Icons.add),
              label: const Text('Post another load'),
            ),
            const SizedBox(height: 12),
          ],

          // Driver Controls: Search bar, quick vehicle filter, and active filter tags
          if (!widget.mine) ...[
            _buildSearchBarWithFilterButton(context, isDark),
            const SizedBox(height: 14),
            _buildQuickVehicleChips(isDark),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 12),
              _buildActiveFiltersRow(isDark),
            ],
          ] else ...[
            // Shipper Controls: Status chips & Requests button
            _buildShipperFilterChips(isDark),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => context.push('/requests'),
              icon: const Icon(Icons.pending_actions_outlined),
              label: const Text('View All Incoming Booking Requests'),
            ),
          ],
          const SizedBox(height: 20),

          // Results Feed
          BlocBuilder<LoadsCubit, ResourceState<LoadsScreenModel>>(
            builder: (context, state) => ResourceView<LoadsScreenModel>(
              state: state,
              retry: refresh,
              builder: (model) {
                final visible = _visibleLoads(model.loads);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section Title & Counter
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          widget.mine
                              ? 'Your Postings (${visible.length})'
                              : 'Available Loads (${visible.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (state.loading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (!widget.mine && visible.isNotEmpty)
                          Text(
                            'Real-time rates',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Empty State or Load Grid
                    if (visible.isEmpty)
                      _buildEmptyState(context, isDark)
                    else
                      LoadGrid(
                        loads: visible,
                        showRequests: widget.mine,
                        onTap: (load) async {
                          await context.push('/loads/${load.id}');
                          if (mounted) await refresh();
                        },
                        onTrackBooking: widget.mine
                            ? (load) => context.push(
                                load.deliveryReportedAt != null
                                    ? '/bookings/${load.bookingId}'
                                    : '/tracking/${load.bookingId}',
                              )
                            : null,
                      ),

                    // Load More Button
                    if (model.hasMore) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: state.loading
                              ? null
                              : () => context.read<LoadsCubit>().more(),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Load More Freight Loads'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Driver Session: Top Hero Marketplace Banner
  Widget _buildDriverMarketplaceBanner(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF13362D), const Color(0xFF1C463A)]
              : [const Color(0xFF193F35), const Color(0xFF265A4B)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193F35).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Stack(
          children: [
            // Watermark truck icon
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                Icons.local_shipping_rounded,
                size: 130,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5E9A9).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFFD5E9A9,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: Color(0xFFD5E9A9),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'SPOT FREIGHT MARKETPLACE',
                              style: TextStyle(
                                color: Color(0xFFD5E9A9),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD5E9A9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: openFilters,
                        icon: const Icon(Icons.tune_rounded, size: 15),
                        label: Text(
                          _activeFilterCount > 0
                              ? 'Filters ($_activeFilterCount)'
                              : 'Filter Route',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Available Freight Loads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Direct shipper contracts, high-paying return loads & instant spot matches.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Metrics Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetricCol(
                          'MARKET COVERAGE',
                          'Pan India',
                          Icons.travel_explore_rounded,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        _buildMetricCol(
                          'DISPATCH TYPE',
                          'Spot & Contract',
                          Icons.speed_rounded,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        _buildMetricCol(
                          'SETTLEMENT',
                          'Direct Payout',
                          Icons.currency_rupee_rounded,
                          color: const Color(0xFFD5E9A9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shipper Header
  Widget _buildShipperHeader(BuildContext context, bool isDark) {
    return PageHeading(
      'Your shipments',
      'My loads',
      'Every listing, every request, in one place.',
    );
  }

  Widget _buildMetricCol(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color ?? const Color(0xFFD5E9A9)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // Search input with quick filter button
  Widget _buildSearchBarWithFilterButton(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2421) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: search,
              onChanged: (value) => setState(() => searchQuery = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search city, cargo, or route...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF193F35),
                ),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          search.clear();
                          setState(() => searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Dedicated Filters Button with Badge
        Material(
          color: _activeFilterCount > 0
              ? const Color(0xFF193F35)
              : (isDark ? const Color(0xFF1E2421) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: openFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _activeFilterCount > 0
                      ? const Color(0xFF193F35)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: _activeFilterCount > 0
                        ? const Color(0xFFD5E9A9)
                        : (isDark ? Colors.white70 : const Color(0xFF193F35)),
                  ),
                  if (_activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5E9A9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF193F35),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Horizontal Quick Vehicle Body Type Filter
  Widget _buildQuickVehicleChips(bool isDark) {
    final vehicleList = [
      (null, 'All Vehicles'),
      ('Container', 'Container'),
      ('Open truck', 'Open truck'),
      ('Trailer', 'Trailer'),
      ('Pickup', 'Pickup'),
      ('LCV', 'LCV'),
      ('Mini truck', 'Mini truck'),
      ('Refrigerated', 'Refrigerated'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: vehicleList.map((item) {
          final isSelected = filter.vehicle == item.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(item.$2),
              avatar: item.$1 == null
                  ? Icon(
                      Icons.dashboard_outlined,
                      size: 14,
                      color: isSelected
                          ? const Color(0xFFD5E9A9)
                          : (isDark ? Colors.white60 : Colors.black54),
                    )
                  : Icon(
                      Icons.local_shipping_outlined,
                      size: 14,
                      color: isSelected
                          ? const Color(0xFFD5E9A9)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFD5E9A9)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF193F35),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF0F4F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF193F35)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              onSelected: (_) {
                setState(() {
                  filter = LoadFilter(
                    vehicle: item.$1,
                    pickup: filter.pickup,
                    destination: filter.destination,
                    maxWeightTonnes: filter.maxWeightTonnes,
                    minVehicleLengthFt: filter.minVehicleLengthFt,
                    status: filter.status,
                  );
                });
                refresh();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Active filter summary tag pills
  Widget _buildActiveFiltersRow(bool isDark) {
    final tags = <Widget>[];

    if (filter.pickup != null && filter.pickup!.isNotEmpty) {
      tags.add(
        _buildFilterTag(
          'Origin: ${filter.pickup}',
          () => setState(() {
            filter = LoadFilter(
              pickup: null,
              destination: filter.destination,
              vehicle: filter.vehicle,
              maxWeightTonnes: filter.maxWeightTonnes,
              minVehicleLengthFt: filter.minVehicleLengthFt,
            );
            refresh();
          }),
          isDark,
        ),
      );
    }

    if (filter.destination != null && filter.destination!.isNotEmpty) {
      tags.add(
        _buildFilterTag(
          'Drop: ${filter.destination}',
          () => setState(() {
            filter = LoadFilter(
              pickup: filter.pickup,
              destination: null,
              vehicle: filter.vehicle,
              maxWeightTonnes: filter.maxWeightTonnes,
              minVehicleLengthFt: filter.minVehicleLengthFt,
            );
            refresh();
          }),
          isDark,
        ),
      );
    }

    if (filter.maxWeightTonnes != null) {
      tags.add(
        _buildFilterTag(
          '≤ ${filter.maxWeightTonnes!.toStringAsFixed(0)} t',
          () => setState(() {
            filter = LoadFilter(
              pickup: filter.pickup,
              destination: filter.destination,
              vehicle: filter.vehicle,
              maxWeightTonnes: null,
              minVehicleLengthFt: filter.minVehicleLengthFt,
            );
            refresh();
          }),
          isDark,
        ),
      );
    }

    if (filter.minVehicleLengthFt != null) {
      tags.add(
        _buildFilterTag(
          '≤ ${filter.minVehicleLengthFt!.toStringAsFixed(0)} ft',
          () => setState(() {
            filter = LoadFilter(
              pickup: filter.pickup,
              destination: filter.destination,
              vehicle: filter.vehicle,
              maxWeightTonnes: filter.maxWeightTonnes,
              minVehicleLengthFt: null,
            );
            refresh();
          }),
          isDark,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: tags),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () {
            setState(() => filter = const LoadFilter());
            refresh();
          },
          child: const Text(
            'Clear all',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF193F35),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTag(String label, VoidCallback onRemove, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF193F35).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF193F35).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF193F35),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: Color(0xFF193F35),
            ),
          ),
        ],
      ),
    );
  }

  // Shipper filter chips
  Widget _buildShipperFilterChips(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [null, 'open', 'assigned', 'in_transit', 'completed', 'cancelled']
              .map(
                (status) => ChoiceChip(
                  label: Text(status == null ? 'All' : statusLabel(status)),
                  selected: filter.status == status,
                  selectedColor: const Color(0xFF193F35),
                  labelStyle: TextStyle(
                    color: filter.status == status
                        ? const Color(0xFFD5E9A9)
                        : null,
                    fontWeight: filter.status == status
                        ? FontWeight.bold
                        : null,
                  ),
                  onSelected: (_) {
                    setState(() => filter = LoadFilter(status: status));
                    refresh();
                  },
                ),
              )
              .toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2421) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF193F35).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              size: 36,
              color: Color(0xFF193F35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.mine
                ? 'No shipments posted yet'
                : searchQuery.isNotEmpty
                ? 'No freight matching “$searchQuery”'
                : 'No matching loads on this route',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            widget.mine
                ? 'Post a freight listing to connect with verified fleet operators.'
                : 'Try adjusting your route filters, changing vehicle body type, or expanding your weight limits.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          if (widget.mine)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF193F35),
                foregroundColor: const Color(0xFFD5E9A9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => context.go('/loads/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Post a Load',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF193F35),
                foregroundColor: const Color(0xFFD5E9A9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                search.clear();
                setState(() {
                  searchQuery = '';
                  filter = const LoadFilter();
                });
                refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Reset All Filters & Show All',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  List<LoadModel> _visibleLoads(List<LoadModel> loads) {
    if (widget.mine || searchQuery.isEmpty) return loads;
    final term = searchQuery.toLowerCase();
    return loads
        .where(
          (load) => [
            load.pickup,
            load.destination,
            load.cargo,
            load.vehicle,
          ].join(' ').toLowerCase().contains(term),
        )
        .toList();
  }
}

// Redesigned Bottom Sheet Filter
class _LoadFiltersSheet extends StatefulWidget {
  const _LoadFiltersSheet({required this.filter});
  final LoadFilter filter;

  @override
  State<_LoadFiltersSheet> createState() => _LoadFiltersSheetState();
}

class _LoadFiltersSheetState extends State<_LoadFiltersSheet> {
  late final TextEditingController pickup;
  late final TextEditingController destination;
  late final TextEditingController capacity;
  late final TextEditingController length;
  late String? vehicle;

  @override
  void initState() {
    super.initState();
    pickup = TextEditingController(text: widget.filter.pickup);
    destination = TextEditingController(text: widget.filter.destination);
    capacity = TextEditingController(
      text: widget.filter.maxWeightTonnes?.toString() ?? '',
    );
    length = TextEditingController(
      text: widget.filter.minVehicleLengthFt?.toString() ?? '',
    );
    vehicle = widget.filter.vehicle;
  }

  @override
  void dispose() {
    pickup.dispose();
    destination.dispose();
    capacity.dispose();
    length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF193F35).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF193F35),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Route & Truck Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Specify your target pickup hub, return destination, or vehicle capacity.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // Pickup Place
            AppTextField(
              controller: pickup,
              label: 'Origin / Pickup City (e.g. Pune, Bhiwandi)',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // Destination Place
            AppTextField(
              controller: destination,
              label: 'Destination / Drop City (e.g. Delhi, Chennai)',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // Vehicle Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: vehicle,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Vehicle Body Type',
                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Any Vehicle Type'),
                ),
                ...vehicleTypes.map(
                  (item) => DropdownMenuItem(value: item, child: Text(item)),
                ),
              ],
              onChanged: (value) => setState(() => vehicle = value),
            ),
            const SizedBox(height: 14),

            // Capacity Field
            AppTextField(
              controller: capacity,
              label: 'Max Cargo Weight (Tonnes)',
              hint: 'Loads up to this payload weight',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 14),

            // Length Field
            AppTextField(
              controller: length,
              label: 'Minimum Truck Length (ft)',
              hint: 'Deck length required',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 20),

            // Apply Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF193F35),
                foregroundColor: const Color(0xFFD5E9A9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(
                context,
                LoadFilter(
                  pickup: pickup.text.trim().isEmpty
                      ? null
                      : placeLabel(pickup.text),
                  destination: destination.text.trim().isEmpty
                      ? null
                      : placeLabel(destination.text),
                  vehicle: vehicle,
                  maxWeightTonnes: double.tryParse(capacity.text),
                  minVehicleLengthFt: double.tryParse(length.text),
                ),
              ),
              child: const Text(
                'Apply Route Filters',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),

            // Clear Button
            TextButton(
              onPressed: () => Navigator.pop(context, const LoadFilter()),
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
