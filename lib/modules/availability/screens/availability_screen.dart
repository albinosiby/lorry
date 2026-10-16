import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../../vehicles/models/vehicle_model.dart';
import '../cubit/availability_cubit.dart';
import '../models/availability_screen_model.dart';
import '../models/truck_availability_model.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Live, 2: Closed

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const LocalizedText('Truck Availability Radar'),
        actions: [
          IconButton(
            tooltip: localize(context, 'Refresh Broadcasts'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<AvailabilityCubit>().load(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        backgroundColor: AppTheme.orange,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.radar_rounded, size: 20),
        label: const LocalizedText(
          'Broadcast Truck',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      body: PageBody(
        onRefresh: () => context.read<AvailabilityCubit>().load(),
        child:
            BlocConsumer<
              AvailabilityCubit,
              ResourceState<AvailabilityScreenModel>
            >(
              listener: (context, state) {
                if (state.error != null) showNotice(context, state.error!);
                if (state.notice != null) showNotice(context, state.notice!);
              },
              builder: (context, state) =>
                  ResourceView<AvailabilityScreenModel>(
                    state: state,
                    retry: () => context.read<AvailabilityCubit>().load(),
                    builder: (model) {
                      final allPosts = model.posts;
                      final livePosts = allPosts
                          .where(
                            (p) => p.status.toLowerCase() == 'open' && !p.busy,
                          )
                          .toList();
                      final closedPosts = allPosts
                          .where((p) => p.status.toLowerCase() != 'open')
                          .toList();

                      List<TruckAvailabilityModel> filteredPosts;
                      if (_selectedFilterIndex == 1) {
                        filteredPosts = livePosts;
                      } else if (_selectedFilterIndex == 2) {
                        filteredPosts = closedPosts;
                      } else {
                        filteredPosts = allPosts;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Radar Command Hero Card
                          _buildRadarHero(
                            context,
                            totalBroadcasts: livePosts.length,
                            totalVehicles: model.vehicles.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 18),

                          // 2. Filter Segments
                          if (model.vehicles.isNotEmpty &&
                              model.posts.isNotEmpty) ...[
                            _buildFilterTabs(
                              totalAll: allPosts.length,
                              totalLive: livePosts.length,
                              totalClosed: closedPosts.length,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 3. Main Content
                          if (model.vehicles.isEmpty)
                            _buildNoVehiclesCard(context, isDark)
                          else if (model.posts.isEmpty)
                            _buildEmptyState(context, isDark)
                          else if (filteredPosts.isEmpty)
                            _buildFilteredEmptyState(isDark)
                          else
                            ...filteredPosts.map(
                              (post) =>
                                  _buildAvailabilityCard(context, post, isDark),
                            ),

                          const SizedBox(height: 88),
                        ],
                      );
                    },
                  ),
            ),
      ),
    );
  }

  // ─── Radar Command Hero Header ─────────────────────────────────────────────

  Widget _buildRadarHero(
    BuildContext context, {
    required int totalBroadcasts,
    required int totalVehicles,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2018), Color(0xFF193F35), Color(0xFF143028)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6BDB9C).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Radar Icon + Pulse Badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6BDB9C).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6BDB9C).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFF6BDB9C),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalizedText(
                      'Route Availability Radar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    LocalizedText(
                      'Live Freight Matching Network',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Glowing Live Pulse
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6BDB9C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6BDB9C).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6BDB9C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const LocalizedText(
                      'ACTIVE',
                      style: TextStyle(
                        color: Color(0xFF6BDB9C),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subtitle description
          LocalizedText(
            'Broadcast empty vehicles to shippers along your return corridor. Avoid empty running and secure instant spot loads.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Telemetry Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                _buildHeroMetric(
                  icon: Icons.cell_tower_rounded,
                  label: 'Live Broadcasts',
                  value: '$totalBroadcasts',
                  valueColor: const Color(0xFF6BDB9C),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.15),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                _buildHeroMetric(
                  icon: Icons.local_shipping_outlined,
                  label: 'Fleet Ready',
                  value: '$totalVehicles',
                  valueColor: const Color(0xFFFFB899),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.15),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                _buildHeroMetric(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GPS Network',
                  value: 'Ready',
                  valueColor: const Color(0xFF90CAF9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LocalizedText(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Filter Tabs Segment ───────────────────────────────────────────────────

  Widget _buildFilterTabs({
    required int totalAll,
    required int totalLive,
    required int totalClosed,
    required bool isDark,
  }) {
    final filters = [
      ('All', totalAll),
      ('Live Only', totalLive),
      ('Closed', totalClosed),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          final (title, count) = filters[index];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedText(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.75)
                                : const Color(0xFF193F35)),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: LocalizedText(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              selectedColor: const Color(0xFF193F35),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFEBEFEA),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF6BDB9C).withValues(alpha: 0.5)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
              ),
              onSelected: (_) => setState(() => _selectedFilterIndex = index),
            ),
          );
        }),
      ),
    );
  }

  // ─── Availability Broadcast Card ───────────────────────────────────────────

  Widget _buildAvailabilityCard(
    BuildContext context,
    TruckAvailabilityModel post,
    bool isDark,
  ) {
    final isOpen = post.status.toLowerCase() == 'open' && !post.busy;
    final vehicle = post.vehicle;
    final registration = vehicle?.registrationNumber ?? 'COMMERCIAL TRUCK';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen
              ? (isDark
                    ? const Color(0xFF6BDB9C).withValues(alpha: 0.28)
                    : const Color(0xFF193F35).withValues(alpha: 0.15))
              : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06)),
          width: isOpen ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Bar: HSRP Plate & Status Badge
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHsrpPlate(registration),

              if (isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6BDB9C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6BDB9C).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6BDB9C),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const LocalizedText(
                        'LIVE BROADCAST',
                        style: TextStyle(
                          color: Color(0xFF6BDB9C),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: LocalizedText(
                    'CLOSED / EXPIRED',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (post.busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LocalizedText(
                'On assigned trip—not visible to customers. Post availability with your new location after delivery.',
              ),
            ),

          // 2. Vehicle Specs Badges (if vehicle data present)
          if (vehicle != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildSpecPill(
                  icon: Icons.local_shipping_outlined,
                  text: vehicle.vehicleType,
                  isDark: isDark,
                ),
                _buildSpecPill(
                  icon: Icons.scale_outlined,
                  text:
                      '${vehicle.capacityTonnes.toStringAsFixed(1)} T Payload',
                  isDark: isDark,
                ),
                _buildSpecPill(
                  icon: Icons.straighten_rounded,
                  text: '${vehicle.lengthFt.toStringAsFixed(0)} ft Deck',
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // 3. Visual Route Corridor
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF7F8F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Pins & Connector
                Column(
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: Color(0xFF4CAF50),
                    ),
                    Container(
                      width: 2,
                      height: 24,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.15),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppTheme.orange,
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Location Names
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Location
                      LocalizedText(
                        'CURRENT LOCATION',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black45,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        post.currentLocation,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF193F35),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Preferred Destination
                      LocalizedText(
                        'PREFERRED CORRIDOR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black45,
                          letterSpacing: 0.5,
                        ),
                      ),
                      LocalizedText(
                        post.preferredDestination?.isNotEmpty == true
                            ? post.preferredDestination!
                            : 'Open to any destination corridor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: post.preferredDestination?.isNotEmpty == true
                              ? AppTheme.orange
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Driver Notes / Requirements Box
          if (post.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppTheme.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.note,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF333333),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 5. Card Footer: Date posted + Close Action
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black45,
              ),
              const SizedBox(width: 5),
              LocalizedText(
                'Available from ${_formatDate(post.availableFrom)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black54,
                ),
              ),

              if (isOpen)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                    side: BorderSide(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _confirmClosePost(context, post.id),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const LocalizedText(
                    'Close Broadcast',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── HSRP Indian License Plate Widget ──────────────────────────────────────

  Widget _buildHsrpPlate(String registrationNumber) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBF8),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF1B1B1B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0038A8),
                    width: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              const LocalizedText(
                'IND',
                style: TextStyle(
                  fontSize: 6.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0038A8),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 7),
          LocalizedText(
            registrationNumber,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecPill({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF0F4F1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? const Color(0xFF6BDB9C) : const Color(0xFF193F35),
          ),
          const SizedBox(width: 4),
          LocalizedText(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty & Helper States ─────────────────────────────────────────────────

  Widget _buildNoVehiclesCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 32,
              color: AppTheme.orange,
            ),
          ),
          const SizedBox(height: 16),
          LocalizedText(
            'Register a Truck to Start Broadcasting',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF193F35),
            ),
          ),
          const SizedBox(height: 8),
          LocalizedText(
            'Payload capacity, body dimensions, and vehicle specs are needed before shippers can match loads with your truck.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Manage My Trucks',
            icon: Icons.add_rounded,
            onPressed: () => context.push('/driver/vehicles'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF6BDB9C).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6BDB9C).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.radar_rounded,
              size: 38,
              color: Color(0xFF6BDB9C),
            ),
          ),
          const SizedBox(height: 18),
          LocalizedText(
            'No Active Availability Broadcasts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF193F35),
            ),
          ),
          const SizedBox(height: 8),
          LocalizedText(
            'Broadcast where your truck is currently stationed. Shippers in your corridor can immediately invite you to spot loads.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const LocalizedText(
              'Broadcast Truck Now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: 40,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black26,
          ),
          const SizedBox(height: 12),
          LocalizedText(
            'No broadcasts match this filter',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions & Dialogs ─────────────────────────────────────────────────────

  Future<void> _confirmClosePost(BuildContext context, String postId) async {
    final confirmed = await confirmAction(
      context,
      'Close truck broadcast?',
      'Customers and shippers will no longer see this truck available on their load-matching radar.',
      confirm: 'Close Broadcast',
    );
    if (confirmed && context.mounted) {
      context.read<AvailabilityCubit>().closePost(postId);
    }
  }

  Future<void> _openForm(BuildContext context) async {
    final model = context.read<AvailabilityCubit>().state.data;
    if (model == null) return;
    if (model.vehicles.isEmpty) {
      context.push('/driver/vehicles');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AvailabilityCubit>(),
        child: _AvailabilityForm(vehicles: model.vehicles),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[local.month - 1];
    final h = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $m, $h:$minute $ampm';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Bottom Sheet Posting Modal Form
// ─────────────────────────────────────────────────────────────────────────────

class _AvailabilityForm extends StatefulWidget {
  const _AvailabilityForm({required this.vehicles});
  final List<VehicleModel> vehicles;

  @override
  State<_AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends State<_AvailabilityForm> {
  final form = GlobalKey<FormState>();
  final currentLocation = TextEditingController();
  final destination = TextEditingController();
  final note = TextEditingController();

  late String vehicleId;
  double? latitude, longitude;
  bool isDetectingGps = false;

  final List<String> _hubSuggestions = const [
    'Aluva, Kochi',
    'Willingdon Island, Kochi',
    'Kozhikode (Calicut)',
    'Thrissur Hub',
    'Palakkad Gateway',
    'Coimbatore Cargo Yard',
    'Bengaluru Logistics Park',
  ];

  final List<String> _corridorSuggestions = const [
    'Kozhikode & Malabar',
    'Coimbatore & Tiruppur',
    'Bengaluru Corridor',
    'Chennai Corridor',
    'Kochi Port Hub',
    'Any Return Corridor',
  ];

  final List<String> _quickNotePills = const [
    'Return load preferred',
    'Available after 3 PM',
    'Full truckload (FTL)',
    'Tarp-covered cargo only',
    'Immediate dispatch ready',
  ];

  @override
  void initState() {
    super.initState();
    vehicleId = widget.vehicles
        .firstWhere((v) => v.isDefault, orElse: () => widget.vehicles.first)
        .id;
  }

  @override
  void dispose() {
    currentLocation.dispose();
    destination.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Form(
          key: form,
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
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cell_tower_rounded,
                      color: AppTheme.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalizedText(
                          'Broadcast Truck Availability',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF193F35),
                          ),
                        ),
                        LocalizedText(
                          'Make vehicle discoverable to spot shippers',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Step 1: Select Fleet Vehicle ─────────────────────────────
              LocalizedText(
                '1. SELECT TRUCK FROM FLEET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF193F35),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.vehicles.map((v) {
                    final isSelected = v.id == vehicleId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => vehicleId = v.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? const Color(0xFF193F35)
                                      : const Color(0xFFEAF5EE))
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFF7F8F2)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6BDB9C)
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.08)),
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildMiniHsrp(v.registrationNumber),
                                  const SizedBox(width: 8),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Color(0xFF6BDB9C),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LocalizedText(
                                '${v.capacityTonnes.toStringAsFixed(1)} T · ${localize(context, v.vehicleType)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Step 2: Current Location & GPS ───────────────────────────
              LocalizedText(
                '2. CURRENT STATION & GPS LOCATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF193F35),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: currentLocation,
                label: 'Current location name',
                hint: 'e.g. Aluva Cargo Yard, Ernakulam',
                textCapitalization: TextCapitalization.words,
                validator: Validators.required,
              ),

              // One-Tap GPS Detection Button & Status
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: latitude != null
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF0F4F1)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: latitude != null
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      latitude != null
                          ? Icons.gps_fixed_rounded
                          : Icons.my_location_rounded,
                      size: 18,
                      color: latitude != null
                          ? const Color(0xFF4CAF50)
                          : AppTheme.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            latitude != null
                                ? 'GPS Position Verified'
                                : 'Live GPS Coordinate Required',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: latitude != null
                                  ? const Color(0xFF4CAF50)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (latitude != null)
                            LocalizedText(
                              '${latitude!.toStringAsFixed(4)}° N, ${longitude!.toStringAsFixed(4)}° E',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: isDetectingGps ? null : _detectGps,
                      icon: isDetectingGps
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 14),
                      label: LocalizedText(
                        latitude == null ? 'Acquire GPS' : 'Update',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Location suggestions quick chips
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _hubSuggestions.map((hub) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: LocalizedText(
                          hub,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            currentLocation.text = hub;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // ─── Step 3: Preferred Destination ────────────────────────────
              LocalizedText(
                '3. PREFERRED HEADING / CORRIDOR (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF193F35),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: destination,
                label: 'Destination city or corridor',
                hint: 'e.g. Kozhikode, Kannur, Coimbatore',
                textCapitalization: TextCapitalization.words,
              ),

              // Destination suggestions quick chips
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _corridorSuggestions.map((corridor) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: LocalizedText(
                          corridor,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            destination.text = corridor;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // ─── Step 4: Driver Remarks & Preferences ─────────────────────
              LocalizedText(
                '4. FREIGHT PREFERENCES & REMARKS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF193F35),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: note,
                label: 'Notes for shippers (optional)',
                hint:
                    'e.g. Return load preferred, ready for pickup immediately',
                lines: 3,
                maxLength: 500,
              ),

              // Quick Note Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickNotePills.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: LocalizedText(
                          '+ $p',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            if (note.text.trim().isEmpty) {
                              note.text = p;
                            } else {
                              note.text = '${note.text.trim()}, $p';
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),

              // ─── Submit Action ─────────────────────────────────────────────
              BlocBuilder<
                AvailabilityCubit,
                ResourceState<AvailabilityScreenModel>
              >(
                builder: (context, state) => AppButton(
                  label: 'Start Live Broadcast',
                  icon: Icons.radar_rounded,
                  busy: state.busy,
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    if (latitude == null || longitude == null) {
                      showNotice(
                        context,
                        'Please tap "Acquire GPS" to link your live coordinates before broadcasting.',
                      );
                      return;
                    }

                    final ok = await context.read<AvailabilityCubit>().save(
                      AvailabilityDraft(
                        vehicleId: vehicleId,
                        currentLocation: currentLocation.text,
                        preferredDestination: destination.text,
                        note: note.text,
                        availableFrom: DateTime.now(),
                        latitude: latitude,
                        longitude: longitude,
                      ),
                    );
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniHsrp(String reg) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBF8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1B1B1B), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: LocalizedText(
        reg,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Future<void> _detectGps() async {
    setState(() => isDetectingGps = true);
    try {
      final loc = await context.read<AvailabilityCubit>().currentLocation();
      if (!mounted) return;
      if (!loc.available || loc.latitude == null || loc.longitude == null) {
        showNotice(
          context,
          'GPS signal not available. Please ensure location service is turned on.',
        );
        return;
      }
      setState(() {
        latitude = loc.latitude;
        longitude = loc.longitude;
        if (currentLocation.text.trim().isEmpty) {
          currentLocation.text =
              'Live GPS Position (${latitude!.toStringAsFixed(3)}, ${longitude!.toStringAsFixed(3)})';
        }
      });
    } finally {
      if (mounted) setState(() => isDetectingGps = false);
    }
  }
}
