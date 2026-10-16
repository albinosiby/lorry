import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../widgets/truck_length_input.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lorry_link/config/routes/routes.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import '../../loads/models/load_model.dart';
import '../cubit/vehicles_cubit.dart';
import '../models/vehicle_model.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const LocalizedText('My Fleet & Trucks'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: localize(context, 'Refresh trucks'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<VehiclesCubit>().load(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        backgroundColor: const Color(0xFF193F35),
        foregroundColor: const Color(0xFFD5E9A9),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const LocalizedText(
          'Add Truck',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      body: PageBody(
        onRefresh: () => context.read<VehiclesCubit>().load(),
        child: BlocConsumer<VehiclesCubit, ResourceState<List<VehicleModel>>>(
          listener: (context, state) {
            if (state.error != null) showNotice(context, state.error!);
            if (state.notice != null) showNotice(context, state.notice!);
          },
          builder: (context, state) => ResourceView<List<VehicleModel>>(
            state: state,
            retry: () => context.read<VehiclesCubit>().load(),
            builder: (trucks) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hero Overview Card
                _buildFleetOverviewBanner(context, trucks, isDark),
                const SizedBox(height: 24),

                // Section Title & Counter
                Wrap(
                  spacing: 8,
                  runSpacing: 8,

                  children: [
                    LocalizedText(
                      'Registered Fleet (${trucks.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (trucks.isNotEmpty)
                      LocalizedText(
                        'Tap truck for RC & Vault',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Empty State or List of Trucks
                if (trucks.isEmpty)
                  _buildEmptyState(context, isDark)
                else
                  ...trucks.map(
                    (truck) => _buildTruckCard(context, truck, isDark),
                  ),

                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFleetOverviewBanner(
    BuildContext context,
    List<VehicleModel> trucks,
    bool isDark,
  ) {
    final defaultTruck = trucks.cast<VehicleModel?>().firstWhere(
      (t) => t?.isDefault == true,
      orElse: () => trucks.isNotEmpty ? trucks.first : null,
    );

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

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
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
                              Icons.verified_user_rounded,
                              size: 13,
                              color: Color(0xFFD5E9A9),
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: LocalizedText(
                                'FLEET COMMAND',
                                style: TextStyle(
                                  color: Color(0xFFD5E9A9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
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
                        onPressed: () => _edit(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const LocalizedText(
                          'Add Vehicle',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const LocalizedText(
                    'Your Verified Fleet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LocalizedText(
                    'Add your trucks with RC & dimensions to match loads and boost trip earnings.',
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildMetricCol(
                            'TOTAL TRUCKS',
                            '${trucks.length}',
                            Icons.local_shipping_outlined,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        Expanded(
                          child: _buildMetricCol(
                            'PRIMARY VEHICLE',
                            defaultTruck?.registrationNumber ?? 'None',
                            Icons.star_rounded,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        Expanded(
                          child: _buildMetricCol(
                            'MATCH STATUS',
                            trucks.isNotEmpty ? 'Active' : 'Pending',
                            Icons.check_circle_outline_rounded,
                            color: trucks.isNotEmpty
                                ? const Color(0xFFD5E9A9)
                                : Colors.amberAccent,
                          ),
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
            Flexible(
              child: LocalizedText(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTruckCard(
    BuildContext context,
    VehicleModel truck,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1E2421) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: truck.isDefault
              ? const Color(0xFF193F35).withValues(alpha: 0.5)
              : borderColor,
          width: truck.isDefault ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () => context.push('${Routes.vehicles}/${truck.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Number Plate & Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,

                  children: [
                    // Indian HSRP Number Plate
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF111111),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Left blue IND chip
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF0038A8),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const LocalizedText(
                                'IND',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0038A8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Registration text
                          Text(
                            truck.registrationNumber,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        if (truck.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.orange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const LocalizedText(
                              '★ PRIMARY',
                              style: TextStyle(
                                color: AppTheme.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: localize(context, 'Edit truck specs'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _edit(context, truck),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Vehicle Spec Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSpecChip(
                      icon: Icons.local_shipping_outlined,
                      label: truck.vehicleType,
                      isDark: isDark,
                    ),
                    _buildSpecChip(
                      icon: Icons.straighten_rounded,
                      label: '${feetValue(truck.lengthFt)} ft Deck',
                      isDark: isDark,
                    ),
                    _buildSpecChip(
                      icon: Icons.scale_outlined,
                      label:
                          '${truck.capacityTonnes.toStringAsFixed(1)} T Payload',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Card Footer CTA
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFF193F35).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 15,
                        color: Color(0xFF193F35),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: LocalizedText(
                          'RC & Compliance Vault',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF193F35),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: LocalizedText(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFD5E9A9)
                                : const Color(0xFF193F35),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: isDark
                            ? const Color(0xFFD5E9A9)
                            : const Color(0xFF193F35),
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
  }

  Widget _buildSpecChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF3F6F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? const Color(0xFFD5E9A9) : const Color(0xFF193F35),
          ),
          const SizedBox(width: 6),
          LocalizedText(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black87,
            ),
          ),
        ],
      ),
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
              Icons.local_shipping_outlined,
              size: 36,
              color: Color(0xFF193F35),
            ),
          ),
          const SizedBox(height: 18),
          const LocalizedText(
            'No trucks registered yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const LocalizedText(
            'Add your first vehicle with registration number and tonnage capacity to receive load match alerts.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF193F35),
              foregroundColor: const Color(0xFFD5E9A9),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_rounded),
            label: const LocalizedText(
              'Add Your First Truck',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, [VehicleModel? truck]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<VehiclesCubit>(),
        child: VehicleForm(truck: truck),
      ),
    );
    if (saved == true && context.mounted) context.read<VehiclesCubit>().load();
  }
}

class VehicleForm extends StatefulWidget {
  const VehicleForm({super.key, this.truck});
  final VehicleModel? truck;
  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController registration, capacity;
  String? vehicleType, length;
  bool defaultTruck = false;

  @override
  void initState() {
    super.initState();
    final truck = widget.truck;
    registration = TextEditingController(text: truck?.registrationNumber ?? '');
    capacity = TextEditingController(
      text: truck?.capacityTonnes.toString() ?? '',
    );
    vehicleType = truck?.vehicleType;
    length = truck == null ? null : feetValue(truck.lengthFt);
    defaultTruck = truck?.isDefault ?? false;
  }

  @override
  void dispose() {
    registration.dispose();
    capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
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
                      Icons.local_shipping_rounded,
                      color: Color(0xFF193F35),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  LocalizedText(
                    widget.truck == null
                        ? 'Register New Truck'
                        : 'Edit Truck Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LocalizedText(
                'Enter vehicle registration and cargo specifications for automated load matching.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),

              // Registration Field
              AppTextField(
                controller: registration,
                label: 'Registration Number (e.g. MH 12 AB 1234)',
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v?.trim().length ?? 0) < 4
                    ? 'Enter a valid registration number.'
                    : null,
              ),
              const SizedBox(height: 14),

              // Vehicle Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: vehicleType,
                decoration: localizedDecoration(
                  context,
                  InputDecoration(
                    labelText: 'Truck Body / Type',
                    prefixIcon: const Icon(Icons.category_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                isExpanded: true,
                items: vehicleTypes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: LocalizedText(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => vehicleType = value),
                validator: Validators.required,
              ),
              const SizedBox(height: 14),

              // Deck Length Dropdown
              TruckLengthInput(
                value: length,
                label: 'Vehicle Deck Length',
                onChanged: (value) => setState(() => length = value),
              ),
              const SizedBox(height: 14),

              // Load Capacity Field
              AppTextField(
                controller: capacity,
                label: 'Payload Capacity (in Tonnes)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Enter a valid weight in tonnes.'
                    : null,
              ),
              const SizedBox(height: 10),

              // Default Switch Card
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF3F6F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: defaultTruck
                        ? const Color(0xFF193F35).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: SwitchListTile.adaptive(
                  activeThumbColor: const Color(0xFF193F35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  title: const LocalizedText(
                    'Set as Primary Fleet Truck',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const LocalizedText(
                    'This vehicle will be selected first for posting your driver availability.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: defaultTruck,
                  onChanged: (value) => setState(() => defaultTruck = value),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              BlocBuilder<VehiclesCubit, ResourceState<List<VehicleModel>>>(
                builder: (context, state) => AppButton(
                  label: widget.truck == null
                      ? 'Save & Register Truck'
                      : 'Update Truck Specs',
                  busy: state.busy,
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    final ok = await context.read<VehiclesCubit>().save(
                      VehicleDraft(
                        id: widget.truck?.id,
                        registrationNumber: registration.text,
                        vehicleType: vehicleType!,
                        bodyType: vehicleType!,
                        lengthFt: double.parse(length!),
                        capacityTonnes: double.parse(capacity.text),
                        isDefault: defaultTruck,
                      ),
                    );
                    if (ok && context.mounted) Navigator.pop(context, true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
