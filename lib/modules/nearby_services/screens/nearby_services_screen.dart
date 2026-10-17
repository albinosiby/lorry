import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';
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
  NearbyServiceType? type;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<NearbyServicesCubit>();
    if (cubit.state.data == null) {
      cubit.loadNearby();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> refreshNearMe() =>
      context.read<NearbyServicesCubit>().refreshNearMe();

  void selectCategory(NearbyServiceType? value) {
    setState(() {
      type = value;
      search.clear();
    });
    context.read<NearbyServicesCubit>().updateFilters(type: value, query: '');
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Handled with fallback notice */
    }
    if (mounted) {
      showNotice(context, 'Could not open the selected application.');
    }
  }

  void _callNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^+0-9]'), '');
    if (clean.isNotEmpty) {
      _open(Uri(scheme: 'tel', path: clean));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText(
              'Driver Essentials',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            LocalizedText(
              'Highway roadside services & amenities',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: PageBody(
        child:
            BlocBuilder<
              NearbyServicesCubit,
              ResourceState<NearbyServicesScreenModel>
            >(
              builder: (context, state) {
                final model = state.data;
                final location = model?.location;
                final available = location?.available == true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Live GPS Location & Corridor Hero Banner
                    _buildLocationHeroBanner(
                      context,
                      model,
                      location,
                      state.busy,
                    ),
                    const SizedBox(height: 16),

                    // 2. Highway Emergency SOS Strip
                    _buildEmergencyHelplines(context),
                    const SizedBox(height: 18),

                    // 3. Category Selector Carousel
                    _buildCategorySelector(context),
                    const SizedBox(height: 16),

                    // 4. Highway Search Bar with Clear
                    _buildSearchBar(context, state.busy),
                    const SizedBox(height: 14),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            type = null;
                            search.clear();
                          });
                          refreshNearMe();
                        },
                        icon: const Icon(Icons.my_location),
                        label: const LocalizedText('Near me'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LocalizedText(
                      'Closest first · Approximate straight-line distances',
                    ),
                    const SizedBox(height: 12),
                    if (state.error != null)
                      ErrorPanel(state.error!)
                    else if (model != null && !available)
                      _buildGpsOfflineNotice(context, location?.status)
                    else if (model != null)
                      for (final category
                          in type == null ? NearbyServiceType.values : [type!])
                        _buildCategorySection(context, model, category),
                    const SizedBox(height: 36),
                  ],
                );
              },
            ),
      ),
    );
  }

  // ─── 1. Location Hero Banner ───────────────────────────────────────────────

  Widget _buildLocationHeroBanner(
    BuildContext context,
    NearbyServicesScreenModel? model,
    DeviceLocation? location,
    bool busy,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final available = location?.available == true;

    final primaryColor = available
        ? const Color(0xFF2E7D32)
        : const Color(0xFFE65100);

    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: isDark ? .15 : .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? .35 : .2),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: .2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              available
                  ? Icons.my_location_rounded
                  : Icons.location_off_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: available ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LocalizedText(
                        available
                            ? 'GPS Location Active'
                            : busy
                            ? 'Locating your truck…'
                            : 'Location Services Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LocalizedText(
                  available
                      ? (model!.locationLabel.isNotEmpty
                            ? model.locationLabel
                            : 'Lat: ${location!.latitude!.toStringAsFixed(4)}, Long: ${location.longitude!.toStringAsFixed(4)}')
                      : _locationMessage(location?.status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!available) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: localize(context, 'Enable GPS'),
              style: IconButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: .15),
                foregroundColor: primaryColor,
              ),
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: busy
                  ? null
                  : () => context.read<NearbyServicesCubit>().openSettings(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. Highway Emergency Helplines ────────────────────────────────────────

  Widget _buildEmergencyHelplines(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final helplines = [
      (
        label: '1033',
        title: 'Highway SOS',
        color: const Color(0xFFD32F2F),
        icon: Icons.emergency_rounded,
        phone: '1033',
      ),
      (
        label: '108',
        title: 'Ambulance',
        color: const Color(0xFFC2185B),
        icon: Icons.medical_services_rounded,
        phone: '108',
      ),
      (
        label: '112',
        title: 'Police',
        color: const Color(0xFF1976D2),
        icon: Icons.local_police_rounded,
        phone: '112',
      ),
      (
        label: '101',
        title: 'Fire',
        color: const Color(0xFFF57C00),
        icon: Icons.fire_extinguisher_rounded,
        phone: '101',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: Colors.red),
            const SizedBox(width: 6),
            Expanded(
              child: LocalizedText(
                'Highway Emergency Helplines (Toll-Free)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: helplines.map((item) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => _callNumber(item.phone),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: isDark ? .18 : .08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.color.withValues(alpha: .3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 18, color: item.color),
                        const SizedBox(height: 3),
                        LocalizedText(
                          item.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: item.color,
                          ),
                        ),
                        LocalizedText(
                          item.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── 3. Category Selector Carousel ─────────────────────────────────────────

  Widget _buildCategorySelector(BuildContext context) {
    final categories = [null, ...NearbyServiceType.values];

    return SizedBox(
      height: 110 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2.5),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = type == cat;
          final color = _categoryColor(cat);
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => selectCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 104,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: isDark ? .25 : .14)
                    : isDark
                    ? const Color(0xFF1C2822)
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? color
                      : (isDark
                            ? Colors.white.withValues(alpha: .08)
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: .5,
                              )),
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? .2 : .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon(cat), color: color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  LocalizedText(
                    cat?.label ?? 'All Services',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? color
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── 4. Search Bar ─────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context, bool busy) {
    return TextField(
      controller: search,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {});
        context.read<NearbyServicesCubit>().updateFilters(
          type: type,
          query: value.trim(),
        );
      },
      decoration: localizedDecoration(
        context,
        InputDecoration(
          hintText: 'Search petrol pump, mechanic, puncture, dhaba…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: localize(context, 'Clear search'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    search.clear();
                    setState(() {});
                    context.read<NearbyServicesCubit>().updateFilters(
                      type: type,
                      query: '',
                    );
                  },
                ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    NearbyServicesScreenModel model,
    NearbyServiceType category,
  ) {
    final query = model.query.toLowerCase();
    final items = model.services.where((item) {
      if (item.type != category || query.isEmpty) return item.type == category;
      return '${item.name} ${item.address} ${item.type.label}'
          .toLowerCase()
          .contains(query);
    }).toList();
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_icon(category), color: _categoryColor(category)),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  category.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: 290 * scale.clamp(1, 2.5),
                child: ListView.separated(
                  key: ValueKey('services-${category.apiValue}'),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: constraints.maxWidth < 340
                        ? constraints.maxWidth
                        : 300,
                    child: _buildServiceCard(context, items[index]),
                  ),
                ),
              ),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: LocalizedText(
                'No services found within ${model.categoryRadii[category] ?? 50} km.',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, NearbyServiceModel item) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_icon(item.type), color: _categoryColor(item.type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LocalizedText(
              [
                if (item.distanceKm != null)
                  '${item.distanceKm!.toStringAsFixed(1)} km',
                if (item.rating != null) '★ ${item.rating!.toStringAsFixed(1)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (item.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.address, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (item.openNow != null) ...[
              const SizedBox(height: 6),
              LocalizedText(
                item.openNow! ? 'Open now' : 'Closed now',
                style: TextStyle(
                  color: item.openNow! ? Colors.green : theme.colorScheme.error,
                ),
              ),
            ],
            if (item.truckFriendly) const LocalizedText('Truck access mapped'),
            const Spacer(),
            Row(
              children: [
                if (item.phone.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _callNumber(item.phone.split(RegExp(r'[;,]')).first),
                      icon: const Icon(Icons.call_outlined, size: 17),
                      label: const LocalizedText('Call'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _open(
                      Uri.https('www.google.com', '/maps/dir/', {
                        'api': '1',
                        'destination': '${item.latitude},${item.longitude}',
                        'travelmode': 'driving',
                        if (item.provider == 'google')
                          'destination_place_id': item.id,
                      }),
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 17),
                    label: const LocalizedText('Navigate'),
                  ),
                ),
              ],
            ),
            if (item.provider.isNotEmpty)
              InkWell(
                onTap: () => _open(
                  Uri.parse(
                    item.provider == 'google'
                        ? 'https://maps.google.com'
                        : 'https://www.openstreetmap.org/copyright',
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LocalizedText(
                    item.provider == 'google'
                        ? 'Google Maps'
                        : '© OpenStreetMap contributors',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            for (final attribution in item.attributions)
              if ((attribution['displayName']?.toString() ?? '').isNotEmpty)
                LocalizedText(
                  attribution['displayName'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
          ],
        ),
      ),
    );
  }

  // ─── 7. Empty & Offline Notices ───────────────────────────────────────────

  Widget _buildGpsOfflineNotice(
    BuildContext context,
    DeviceLocationStatus? status,
  ) {
    return AppEmptyState(
      'Turn on GPS to find essentials',
      _locationMessage(status),
      icon: Icons.gps_off_rounded,
      action: AppButton(
        label: 'Open Phone Location Settings',
        icon: Icons.settings_outlined,
        onPressed: () => context.read<NearbyServicesCubit>().openSettings(),
      ),
    );
  }

  String _locationMessage(DeviceLocationStatus? status) => switch (status) {
    DeviceLocationStatus.serviceDisabled =>
      'Turn on GPS, then return to discover highway essentials.',
    DeviceLocationStatus.permissionDeniedForever =>
      'Enable location permission in phone settings.',
    DeviceLocationStatus.permissionDenied =>
      'Allow location access to find roadside assistance.',
    _ =>
      'Use your current location to discover roadside stops along your route.',
  };

  IconData _icon(NearbyServiceType? category) => switch (category) {
    null => Icons.grid_view_rounded,
    NearbyServiceType.fuel => Icons.local_gas_station_rounded,
    NearbyServiceType.truckStop => Icons.local_parking_rounded,
    NearbyServiceType.weighbridge => Icons.scale_rounded,
    NearbyServiceType.workshop => Icons.build_rounded,
    NearbyServiceType.tyre => Icons.tire_repair_rounded,
    NearbyServiceType.hospital => Icons.local_hospital_rounded,
    NearbyServiceType.food => Icons.restaurant_rounded,
    NearbyServiceType.hotel => Icons.hotel_rounded,
    NearbyServiceType.serviceCenter => Icons.car_repair_rounded,
  };

  Color _categoryColor(NearbyServiceType? category) => switch (category) {
    null => const Color(0xFF1E88E5),
    NearbyServiceType.fuel => const Color(0xFF2E7D32),
    NearbyServiceType.truckStop => const Color(0xFF0288D1),
    NearbyServiceType.weighbridge => const Color(0xFF00897B),
    NearbyServiceType.workshop => const Color(0xFFF57C00),
    NearbyServiceType.tyre => const Color(0xFF7B1FA2),
    NearbyServiceType.hospital => const Color(0xFFE53935),
    NearbyServiceType.food => const Color(0xFFD84315),
    NearbyServiceType.hotel => const Color(0xFF5D4037),
    NearbyServiceType.serviceCenter => const Color(0xFF455A64),
  };
}
