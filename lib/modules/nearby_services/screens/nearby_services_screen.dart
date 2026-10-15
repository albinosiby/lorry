import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../../../utils/services/location_service.dart';
import '../cubit/nearby_services_cubit.dart';
import '../models/nearby_service_model.dart';
import '../models/nearby_services_screen_model.dart';

class NearbyServicesScreen extends StatefulWidget {
  const NearbyServicesScreen({super.key});

  @override
  State<NearbyServicesScreen> createState() => _NearbyServicesScreenState();
}

class _NearbyServicesScreenState extends State<NearbyServicesScreen> {
  final search = TextEditingController();
  int radiusKm = 10;
  NearbyServiceType? type;

  @override
  void initState() {
    super.initState();
    context.read<NearbyServicesCubit>().locateAndSearch();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void discover({NearbyServiceType? nextType, bool clearType = false}) {
    if (nextType != null || clearType) type = clearType ? null : nextType;
    context.read<NearbyServicesCubit>().locateAndSearch(
      radiusKm: radiusKm,
      type: type,
      query: search.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nearby Roadside Services',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh nearby',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => discover(),
          ),
        ],
      ),
      body: PageBody(
        onRefresh: () async => discover(),
        child: BlocConsumer<
          NearbyServicesCubit,
          ResourceState<NearbyServicesScreenModel>
        >(
          listener: (context, state) {
            if (state.error != null) showNotice(context, state.error!);
          },
          builder: (context, state) {
            final model = state.data;
            if (model == null) {
              return state.error == null
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ErrorPanel(state.error!, retry: discover);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero GPS Location Status Banner
                _buildGpsHeroBanner(context, model.location, state.busy),
                const SizedBox(height: 16),

                // 2. Search Field
                _buildSearchBar(context, state.busy),
                const SizedBox(height: 14),

                // 3. Category Selector Carousel
                _buildCategorySelector(context),
                const SizedBox(height: 14),

                // 4. Radius Filter Pills
                _buildRadiusSelector(context),
                const SizedBox(height: 20),

                // 5. Results Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discovered Places (${model.services.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (state.busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. Service Cards or Location Help / Empty State
                if (!model.location.available)
                  _buildLocationHelpCard(context, model.location)
                else if (state.busy && model.services.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (model.services.isEmpty)
                  _buildEmptyState(context)
                else
                  ...model.services.map((item) => _buildServiceCard(context, item)),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── 1. GPS Location Status Banner ──────────────────────────────────────────

  Widget _buildGpsHeroBanner(
    BuildContext context,
    DeviceLocation location,
    bool busy,
  ) {
    final available = location.available;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: available
              ? (isDark
                  ? [const Color(0xFF143024), const Color(0xFF0F221A)]
                  : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)])
              : (isDark
                  ? [const Color(0xFF381E1E), const Color(0xFF261414)]
                  : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)]),
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: available
              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
              : const Color(0xFFC62828).withValues(alpha: 0.4),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: available
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.16)
                  : const Color(0xFFC62828).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              available ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      available ? 'Current Location Active' : 'GPS Offline',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: available
                            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20))
                            : (isDark ? const Color(0xFFE57373) : const Color(0xFFB71C1C)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? '${location.latitude!.toStringAsFixed(4)}, ${location.longitude!.toStringAsFixed(4)} (GPS Centered)'
                      : _locationMessage(location.status),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (available) {
                discover();
              } else if (location.status == DeviceLocationStatus.serviceDisabled ||
                  location.status == DeviceLocationStatus.permissionDeniedForever) {
                context.read<NearbyServicesCubit>().openSettings();
              } else {
                discover();
              }
            },
            child: Text(
              available ? 'Refresh' : 'Enable',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Modern Search Bar ───────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context, bool busy) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => discover(),
        decoration: InputDecoration(
          hintText: 'Search petrol pump, tyre puncture, hospital, mechanic...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: cs.primary.withValues(alpha: 0.8),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (search.text.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    search.clear();
                    discover();
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Search places',
                  onPressed: busy ? null : discover,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ─── 3. Category Selector Carousel ──────────────────────────────────────────

  Widget _buildCategorySelector(BuildContext context) {
    final categories = [
      (
        type: null,
        label: 'All Services',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF193F35),
      ),
      (
        type: NearbyServiceType.fuel,
        label: 'Fuel Pumps',
        icon: Icons.local_gas_station_rounded,
        color: const Color(0xFFD97706),
      ),
      (
        type: NearbyServiceType.truckStop,
        label: 'Truck Lay-bys',
        icon: Icons.local_parking_rounded,
        color: const Color(0xFF2563EB),
      ),
      (
        type: NearbyServiceType.workshop,
        label: 'Workshops',
        icon: Icons.build_circle_rounded,
        color: const Color(0xFF0D9488),
      ),
      (
        type: NearbyServiceType.tyre,
        label: 'Tyre Works',
        icon: Icons.tire_repair_rounded,
        color: const Color(0xFF059669),
      ),
      (
        type: NearbyServiceType.weighbridge,
        label: 'Weighbridges',
        icon: Icons.scale_rounded,
        color: const Color(0xFF7C3AED),
      ),
      (
        type: NearbyServiceType.hospital,
        label: 'Hospitals',
        icon: Icons.local_hospital_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = type == cat.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => discover(
                nextType: cat.type,
                clearType: cat.type == null,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? cat.color
                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: isSelected ? 1.6 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: cat.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 4. Radius Filter Pills ─────────────────────────────────────────────────

  Widget _buildRadiusSelector(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241D) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.radar_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Search radius:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          for (final option in [5, 10, 25, 50])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => radiusKm = option);
                  discover();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: radiusKm == option
                        ? const Color(0xFF2E7D32)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: radiusKm == option
                          ? const Color(0xFF2E7D32)
                          : cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    '$option km',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: radiusKm == option ? FontWeight.w800 : FontWeight.w600,
                      color: radiusKm == option ? Colors.white : cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 5. Modern Service Card ─────────────────────────────────────────────────

  Widget _buildServiceCard(BuildContext context, NearbyServiceModel item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (color, icon) = switch (item.type) {
      NearbyServiceType.fuel => (
          const Color(0xFFD97706),
          Icons.local_gas_station_rounded
        ),
      NearbyServiceType.truckStop => (
          const Color(0xFF2563EB),
          Icons.local_parking_rounded
        ),
      NearbyServiceType.workshop => (
          const Color(0xFF0D9488),
          Icons.build_circle_rounded
        ),
      NearbyServiceType.tyre => (
          const Color(0xFF059669),
          Icons.tire_repair_rounded
        ),
      NearbyServiceType.weighbridge => (
          const Color(0xFF7C3AED),
          Icons.scale_rounded
        ),
      NearbyServiceType.hospital => (
          const Color(0xFFDC2626),
          Icons.local_hospital_rounded
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13251D) : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),

              // Title and Category Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.type.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        if (item.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.near_me_rounded,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.distanceKm!.toStringAsFixed(1)} km away',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Rating or Open Pill
              if (item.rating != null && item.rating! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Address if available
          if (item.address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    item.address,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Navigation CTA Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.openNow != null)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.openNow!
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.openNow! ? 'Open Now' : 'Check Hours',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: item.openNow!
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _navigate(item),
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: const Text(
                  'Directions',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Services Found in this Radius',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Try widening the search radius (e.g. 25 km or 50 km) or selecting "All Services" above.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() => radiusKm = 25);
              discover(clearType: true);
            },
            icon: const Icon(Icons.radar_rounded, size: 18),
            label: const Text('Expand to 25 km & All Services'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHelpCard(BuildContext context, DeviceLocation location) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC62828).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gps_off_rounded,
                  color: Color(0xFFC62828),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Turn on GPS Location',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      _locationMessage(location.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.location_on_rounded, size: 20),
            label: const Text(
              'Enable GPS Location Now',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            onPressed: () {
              if (location.status == DeviceLocationStatus.serviceDisabled ||
                  location.status == DeviceLocationStatus.permissionDeniedForever) {
                context.read<NearbyServicesCubit>().openSettings();
              } else {
                discover();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigate(NearbyServiceModel item) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${item.latitude},${item.longitude}',
      'travelmode': 'driving',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showNotice(context, 'Could not open Google Maps navigation.');
    }
  }

  String _locationMessage(DeviceLocationStatus status) => switch (status) {
    DeviceLocationStatus.serviceDisabled =>
      'Turn on device location services, then return here.',
    DeviceLocationStatus.permissionDenied =>
      'Allow location access to search the services around you.',
    DeviceLocationStatus.permissionDeniedForever =>
      'Location permission is blocked. Enable it in phone settings.',
    DeviceLocationStatus.ready => '',
  };
}
