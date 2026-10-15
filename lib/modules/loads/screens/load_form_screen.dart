import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:uuid/uuid.dart';

import '../cubit/load_form_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';
import '../../../utils/services/place_search_service.dart';
import '../widgets/location_picker_sheet.dart';

class LoadFormScreen extends StatefulWidget {
  const LoadFormScreen({super.key, this.id});
  final String? id;

  @override
  State<LoadFormScreen> createState() => _LoadFormScreenState();
}

class _LoadFormScreenState extends State<LoadFormScreen> {
  final form = GlobalKey<FormState>();
  final pickupText = TextEditingController();
  final destinationText = TextEditingController();
  final cargo = TextEditingController();
  final price = TextEditingController();
  final weight = TextEditingController();
  final note = TextEditingController();
  final unloadLocations = <TextEditingController>[];
  final unloadTonnes = <TextEditingController>[];
  final unloadLatitudes = <double?>[];
  final unloadLongitudes = <double?>[];

  String draftId = const Uuid().v4();
  String? pickup, destination, vehicle, vehicleLength;
  double? pickupLatitude,
      pickupLongitude,
      destinationLatitude,
      destinationLongitude;
  DateTime? date;
  TimeOfDay? pickupTime;
  bool isNegotiable = true;
  bool populated = false, dirty = false;

  bool get edit => widget.id != null;

  static const _cargoSuggestions = [
    'Textiles & Garments',
    'FMCG & Groceries',
    'Agricultural Produce',
    'Construction Materials',
    'Machinery & Equipment',
    'Steel & Metal Products',
    'Electronics & Appliances',
    'Furniture & Woodwork',
  ];

  static const _quickPriceOffers = ['5000', '12000', '25000', '45000', '75000'];

  @override
  void dispose() {
    pickupText.dispose();
    destinationText.dispose();
    cargo.dispose();
    price.dispose();
    weight.dispose();
    note.dispose();
    _clearUnloadStops();
    super.dispose();
  }

  void _clearUnloadStops() {
    for (final controller in unloadLocations) {
      controller.dispose();
    }
    for (final controller in unloadTonnes) {
      controller.dispose();
    }
    unloadLocations.clear();
    unloadTonnes.clear();
    unloadLatitudes.clear();
    unloadLongitudes.clear();
  }

  void _setUnloadStops(List<UnloadStop> stops) {
    _clearUnloadStops();
    for (final stop in stops) {
      unloadLocations.add(TextEditingController(text: stop.location));
      unloadTonnes.add(
        TextEditingController(
          text: stop.unloadTonnes?.toStringAsFixed(
                stop.unloadTonnes!.truncateToDouble() == stop.unloadTonnes
                    ? 0
                    : 1,
              ) ??
              '',
        ),
      );
      unloadLatitudes.add(stop.latitude);
      unloadLongitudes.add(stop.longitude);
    }
  }

  void _addUnloadStop() => setState(() {
    unloadLocations.add(TextEditingController());
    unloadTonnes.add(TextEditingController());
    unloadLatitudes.add(null);
    unloadLongitudes.add(null);
    dirty = true;
  });

  void _removeUnloadStop(int index) => setState(() {
    unloadLocations.removeAt(index).dispose();
    unloadTonnes.removeAt(index).dispose();
    unloadLatitudes.removeAt(index);
    unloadLongitudes.removeAt(index);
    dirty = true;
  });

  void populate(LoadFormModel? model) {
    if (!edit || populated || model?.load == null) return;
    final load = model!.load!;
    pickup = load.pickupLabel;
    destination = load.destinationLabel;
    pickupText.text = load.pickupLabel;
    destinationText.text = load.destinationLabel;
    pickupLatitude = load.pickupLatitude;
    pickupLongitude = load.pickupLongitude;
    destinationLatitude = load.destinationLatitude;
    destinationLongitude = load.destinationLongitude;
    vehicle = load.vehicle;
    cargo.text = load.cargo;
    price.text = load.price?.toStringAsFixed(2) ?? '';
    weight.text = load.weightTonnes.toString();
    vehicleLength = load.requiredVehicleLengthFt?.toStringAsFixed(0);
    note.text = load.specialNote;
    isNegotiable = load.specialNote.toLowerCase().contains('negotiable') ||
        load.specialNote.isEmpty;
    date = load.pickupDate;
    pickupTime = load.pickupAt == null
        ? null
        : TimeOfDay.fromDateTime(load.pickupAt!.toLocal());
    _setUnloadStops(load.unloadStops);
    populated = true;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      showNotice(context, 'Please fill in all mandatory fields marked in red.');
      return;
    }
    final pName = canonicalLocation(pickupText.text);
    if (pName == null || pName.isEmpty) {
      showNotice(context, 'Pickup location name is mandatory.');
      return;
    }
    final dName = canonicalLocation(destinationText.text);
    if (dName == null || dName.isEmpty) {
      showNotice(context, 'Destination location name is mandatory.');
      return;
    }
    if (pName == dName) {
      showNotice(context, 'Pickup and destination cannot be the same place.');
      return;
    }
    if (pickupLatitude == null || pickupLongitude == null) {
      showNotice(context, 'Please pin the pickup location on the map.');
      return;
    }
    if (destinationLatitude == null || destinationLongitude == null) {
      showNotice(context, 'Please pin the destination location on the map.');
      return;
    }
    final budgetAmount = double.tryParse(price.text.trim());
    if (budgetAmount == null || budgetAmount <= 0) {
      showNotice(context, 'Freight budget is mandatory. Please enter a valid amount.');
      return;
    }
    final payloadTonnes = double.tryParse(weight.text.trim());
    if (payloadTonnes == null || payloadTonnes <= 0) {
      showNotice(context, 'Payload weight is mandatory. Please enter a valid weight.');
      return;
    }
    if (vehicle == null) {
      showNotice(context, 'Please select a required vehicle type.');
      return;
    }
    if (date == null) {
      showNotice(context, 'Please select a pickup date.');
      return;
    }

    final totalUnloadTonnes = unloadTonnes.fold<double>(
      0,
      (sum, controller) => sum + (double.tryParse(controller.text.trim()) ?? 0),
    );
    if (totalUnloadTonnes > double.parse(weight.text.trim())) {
      showNotice(
        context,
        'The combined unloading weight cannot exceed the total load weight.',
      );
      return;
    }

    pickup = pName;
    destination = dName;

    var finalNote = note.text.trim();
    if (isNegotiable) {
      if (!finalNote.toLowerCase().contains('negotiable')) {
        finalNote = finalNote.isEmpty
            ? 'Price is negotiable'
            : '$finalNote · Price is negotiable';
      }
    } else {
      finalNote = finalNote
          .replaceAll(
            RegExp(r'\s*·?\s*Price is negotiable', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'\(Negotiable\)', caseSensitive: false), '')
          .trim();
    }

    final saved = await context.read<LoadFormCubit>().save(
      LoadDraft(
        id: widget.id ?? draftId,
        pickup: pickup!,
        destination: destination!,
        cargo: cargo.text,
        vehicle: vehicle!,
        date: date!,
        price: budgetAmount,
        weightTonnes: double.parse(weight.text),
        requiredVehicleLengthFt: double.tryParse(vehicleLength ?? ''),
        pickupAt: date == null || pickupTime == null
            ? null
            : DateTime(
                date!.year,
                date!.month,
                date!.day,
                pickupTime!.hour,
                pickupTime!.minute,
              ),
        specialNote: finalNote,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        unloadStops: List.generate(
          unloadLocations.length,
          (index) => UnloadStop(
            location: canonicalLocation(unloadLocations[index].text)!,
            unloadTonnes: double.tryParse(unloadTonnes[index].text.trim()),
            latitude: unloadLatitudes[index],
            longitude: unloadLongitudes[index],
          ),
        ),
      ),
      edit: edit,
    );
    if (!saved || !mounted) return;

    setState(() => dirty = false);
    if (edit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return;
    }

    final published = draftId;
    form.currentState?.reset();
    cargo.clear();
    price.clear();
    weight.clear();
    note.clear();
    _clearUnloadStops();
    setState(() {
      draftId = const Uuid().v4();
      pickup = null;
      destination = null;
      pickupLatitude = null;
      pickupLongitude = null;
      destinationLatitude = null;
      destinationLongitude = null;
      pickupText.clear();
      destinationText.clear();
      vehicle = null;
      vehicleLength = null;
      date = null;
      pickupTime = null;
      isNegotiable = true;
      dirty = false;
    });
    context.push('/loads/$published');
  }

  String? canonicalLocation(String? value) {
    final input = value?.trim();
    return input == null || input.isEmpty ? null : placeLabel(input);
  }

  String? validateLocation(String? value) => canonicalLocation(value) == null
      ? 'Enter a pickup or destination place.'
      : null;

  String? _validateWeight(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Payload weight is mandatory.';
    final tonnes = double.tryParse(trimmed);
    return tonnes == null || !tonnes.isFinite || tonnes <= 0 || tonnes > 100
        ? 'Enter a payload weight between 0.1 and 100 tonnes.'
        : null;
  }

  String? _validatePrice(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Freight budget amount is mandatory.';
    final amount = double.tryParse(trimmed);
    return amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > 9999999999
        ? 'Enter a valid freight budget amount greater than ₹0.'
        : null;
  }

  IconData _vehicleIcon(String type) => switch (type.toLowerCase()) {
    'mini truck' => Icons.local_shipping_outlined,
    'pickup' => Icons.airport_shuttle_outlined,
    'lcv' => Icons.local_shipping_outlined,
    'open truck' => Icons.rv_hookup_outlined,
    'container' => Icons.inventory_2_outlined,
    'trailer' => Icons.departure_board_outlined,
    'refrigerated' => Icons.ac_unit_outlined,
    _ => Icons.local_shipping_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final formBody = PageBody(
      narrow: true,
      child: BlocConsumer<LoadFormCubit, ResourceState<LoadFormModel>>(
        listener: (context, state) {
          populate(state.data);
          if (state.error != null) showNotice(context, state.error!);
          if (state.notice != null) showNotice(context, state.notice!);
        },
        builder: (context, state) {
          populate(state.data);
          if (edit && state.data == null) {
            return state.error != null
                ? ErrorPanel(
                    state.error!,
                    retry: () => context.read<LoadFormCubit>().load(widget.id!),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  );
          }
          return Form(
            key: form,
            onChanged: () {
              if (!dirty) setState(() => dirty = true);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Header Banner
                _buildHeroBanner(context),
                const SizedBox(height: 18),

                // 2. Section 01: Route Corridor
                _buildRouteSection(context),
                const SizedBox(height: 18),

                // 3. Section 02: Cargo & Vehicle Specifications
                _buildCargoSection(context),
                const SizedBox(height: 18),

                // 4. Section 03: Pickup Schedule & Freight Offer
                _buildScheduleSection(context),
                const SizedBox(height: 22),

                // 5. Bottom Action & Summary Card
                _buildPublishCard(context, state),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop ||
            !await confirmAction(
              context,
              'Discard changes?',
              'Your unsaved load details will be lost.',
              confirm: 'Discard',
            ) ||
            !context.mounted) {
          return;
        }
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.pop();
        });
      },
      child: edit
          ? Scaffold(
              appBar: AppBar(title: const Text('Edit Shipment')),
              body: formBody,
            )
          : formBody,
    );
  }

  // ─── 1. Hero Header Banner ──────────────────────────────────────────────────

  Widget _buildHeroBanner(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: edit
              ? (dark
                  ? [const Color(0xFF1B2D35), const Color(0xFF101B20)]
                  : [const Color(0xFF1E3A47), const Color(0xFF285366)])
              : (dark
                  ? [const Color(0xFF132E27), const Color(0xFF0D1E19)]
                  : [const Color(0xFF193F35), const Color(0xFF265A4B)]),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: edit
                ? const Color(0xFF1E3A47).withValues(alpha: .3)
                : const Color(0xFF193F35).withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(
              Icons.local_shipping_outlined,
              size: 100,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (edit
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFD5E9A9))
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (edit
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFFD5E9A9))
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: edit
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFFD5E9A9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      edit ? 'EDIT SHIPMENT POSTING' : 'FREIGHT BROADCAST RADAR',
                      style: TextStyle(
                        color: edit
                            ? const Color(0xFFBAE6FD)
                            : const Color(0xFFD5E9A9),
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                edit ? 'Update Your Cargo Load' : 'Post a Load to Fleets',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                edit
                    ? 'Keep pickup route, weight, and freight offers accurate for drivers.'
                    : 'Broadcast your cargo to verified fleet operators across India for quick quotes and prompt truck assignment.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Step Pipeline Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _pipelineStep('1', 'Route Corridor', active: true),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    _pipelineStep(
                      '2',
                      'Cargo & Fleet',
                      active: pickup != null && destination != null,
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    _pipelineStep(
                      '3',
                      'Schedule & Bid',
                      active: vehicle != null && weight.text.isNotEmpty,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pipelineStep(String num, String title, {required bool active}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFFD5E9A9)
                : Colors.white.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                color: active ? const Color(0xFF13362D) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── 2. Section 01: Route Corridor ──────────────────────────────────────────

  Widget _buildRouteSection(BuildContext context) {
    return _CardSection(
      stepNumber: '01',
      title: 'Route Corridor',
      subtitle: 'Specify where goods are picked up and where they are delivered.',
      icon: Icons.alt_route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pickup Origin Node (Mandatory)
          _RouteNode(
            nodeType: _RouteNodeType.pickup,
            label: 'Pickup City / Place *',
            hint: 'e.g. Kochi, Ernakulam (Mandatory)',
            controller: pickupText,
            latitude: pickupLatitude,
            longitude: pickupLongitude,
            onChanged: (val) => setState(() {
              pickup = canonicalLocation(val);
              pickupLatitude = null;
              pickupLongitude = null;
            }),
            onLocationPicked: (selected) {
              setState(() {
                pickupLatitude = selected.latitude;
                pickupLongitude = selected.longitude;
                if (selected.placeName != null &&
                    selected.placeName!.trim().isNotEmpty) {
                  pickupText.text = selected.placeName!;
                  pickup = canonicalLocation(selected.placeName!);
                }
                dirty = true;
              });
            },
            searchPlace: context.read<LoadFormCubit>().searchPlace,
            validator: (val) => canonicalLocation(val) == null
                ? 'Pickup location name is mandatory.'
                : null,
          ),
          const SizedBox(height: 12),

          // Intermediate Unload Stops List
          if (unloadLocations.isNotEmpty) ...[
            for (var i = 0; i < unloadLocations.length; i++) ...[
              _buildUnloadStopCard(i),
              const SizedBox(height: 12),
            ],
          ],

          // Add Intermediate Stop Button
          if (unloadLocations.length < 10)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _addUnloadStop,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text(
                  'Add Intermediate Unload Stop (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),

          // Final Destination Node (Mandatory)
          _RouteNode(
            nodeType: _RouteNodeType.destination,
            label: 'Destination City / Place *',
            hint: 'e.g. Bengaluru, Karnataka (Mandatory)',
            controller: destinationText,
            latitude: destinationLatitude,
            longitude: destinationLongitude,
            onChanged: (val) => setState(() {
              destination = canonicalLocation(val);
              destinationLatitude = null;
              destinationLongitude = null;
            }),
            onLocationPicked: (selected) {
              setState(() {
                destinationLatitude = selected.latitude;
                destinationLongitude = selected.longitude;
                if (selected.placeName != null &&
                    selected.placeName!.trim().isNotEmpty) {
                  destinationText.text = selected.placeName!;
                  destination = canonicalLocation(selected.placeName!);
                }
                dirty = true;
              });
            },
            searchPlace: context.read<LoadFormCubit>().searchPlace,
            validator: (value) {
              final loc = canonicalLocation(value);
              if (loc == null) return 'Destination location name is mandatory.';
              if (loc == canonicalLocation(pickupText.text)) {
                return 'Destination must be different from pickup.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnloadStopCard(int index) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFFEF6C00),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Intermediate Stop #${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove Stop',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => _removeUnloadStop(index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RouteNode(
            nodeType: _RouteNodeType.waypoint,
            label: 'Stop Location',
            hint: 'e.g. Coimbatore, Tamil Nadu',
            controller: unloadLocations[index],
            latitude: unloadLatitudes[index],
            longitude: unloadLongitudes[index],
            onChanged: (val) => setState(() {
              unloadLatitudes[index] = null;
              unloadLongitudes[index] = null;
            }),
            onLocationPicked: (selected) {
              setState(() {
                unloadLatitudes[index] = selected.latitude;
                unloadLongitudes[index] = selected.longitude;
                if (selected.placeName != null &&
                    selected.placeName!.trim().isNotEmpty) {
                  unloadLocations[index].text = selected.placeName!;
                }
                dirty = true;
              });
            },
            searchPlace: context.read<LoadFormCubit>().searchPlace,
            validator: validateLocation,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: unloadTonnes[index],
            label: 'Weight to unload (tonnes, optional)',
            hint: 'e.g. 1.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final tonnes = double.tryParse(value.trim());
              final total = double.tryParse(weight.text.trim());
              return tonnes == null || !tonnes.isFinite || tonnes <= 0
                  ? 'Enter a positive weight.'
                  : total != null && tonnes > total
                  ? 'Cannot exceed total load weight.'
                  : null;
            },
          ),
        ],
      ),
    );
  }

  // ─── 3. Section 02: Cargo & Vehicle Specifications ─────────────────────────

  Widget _buildCargoSection(BuildContext context) {
    return _CardSection(
      stepNumber: '02',
      title: 'Cargo & Vehicle',
      subtitle: 'Specify what materials are carried and the required truck body.',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cargo Description Field (Mandatory)
          AppTextField(
            controller: cargo,
            label: 'Cargo description *',
            hint: 'e.g. 50 Cartons of Readymade Garments (Mandatory)',
            lines: 2,
            maxLength: 2000,
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Cargo description is mandatory (at least 3 characters).'
                : null,
          ),
          const SizedBox(height: 8),

          // Quick Cargo Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _cargoSuggestions.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        cargo.text = tag;
                        dirty = true;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Vehicle Type Selector Grid
          _buildVehicleSelector(context),
          const SizedBox(height: 18),

          // Weight & Length Side-by-Side (Payload Mandatory)
          _FormPair(
            first: AppTextField(
              controller: weight,
              label: 'Payload weight (tonnes) *',
              hint: 'e.g. 5.5 (Mandatory)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateWeight,
            ),
            second: _buildVehicleLengthSelector(context),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REQUIRED VEHICLE TYPE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (vehicle != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  vehicle!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vehicleTypes.map((type) {
            final isSel = vehicle == type;
            final icon = _vehicleIcon(type);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                vehicle = type;
                dirty = true;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? cs.primaryContainer
                      : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.65),
                    width: isSel ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSel ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // Hidden FormField validator for vehicle type
        FormField<String>(
          key: ValueKey('vehicle-$vehicle-$draftId'),
          initialValue: vehicle,
          validator: (_) =>
              vehicle == null ? 'Please select a required vehicle type.' : null,
          builder: (field) => field.hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                      color: cs.error,
                      fontSize: 12,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildVehicleLengthSelector(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('length-$vehicleLength-$draftId'),
      initialValue: vehicleLength,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Truck length (optional)',
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Any length'),
        ),
        ...vehicleLengthOptions.map(
          (len) => DropdownMenuItem<String>(
            value: len,
            child: Text('$len ft body'),
          ),
        ),
      ],
      onChanged: (val) {
        setState(() {
          vehicleLength = val;
          dirty = true;
        });
      },
    );
  }

  // ─── 4. Section 03: Pickup Schedule & Freight Offer ────────────────────────

  Widget _buildScheduleSection(BuildContext context) {
    return _CardSection(
      stepNumber: '03',
      title: 'Schedule & Pricing',
      subtitle: 'Schedule pickup timing and provide your freight budget.',
      icon: Icons.calendar_month_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date & Time Scheduling Tiles
          Row(
            children: [
              Expanded(
                child: _ScheduleTile(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  label: 'PICKUP DATE',
                  value: date == null
                      ? 'Select Date'
                      : DateFormat('d MMM yyyy').format(date!),
                  subtitle: date == null
                      ? 'Tap to pick date'
                      : DateFormat('EEEE').format(date!),
                  isSelected: date != null,
                  onTap: () async {
                    final today = DateUtils.dateOnly(DateTime.now());
                    final selected = await showDatePicker(
                      context: context,
                      initialDate:
                          date == null || date!.isBefore(today) ? today : date!,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 730)),
                    );
                    if (selected == null) return;
                    setState(() {
                      date = selected;
                      dirty = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScheduleTile(
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFF0284C7),
                  label: 'PICKUP TIME',
                  value: pickupTime == null
                      ? 'Flexible Time'
                      : pickupTime!.format(context),
                  subtitle: pickupTime == null
                      ? 'Tap for fixed time'
                      : 'Fixed dispatch',
                  isSelected: pickupTime != null,
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: pickupTime ?? TimeOfDay.now(),
                    );
                    if (selected == null) return;
                    setState(() {
                      pickupTime = selected;
                      dirty = true;
                    });
                  },
                ),
              ),
            ],
          ),
          // Hidden FormField validator for pickup date
          FormField<DateTime>(
            key: ValueKey('date-$draftId-$populated'),
            initialValue: date,
            validator: (_) => date == null
                ? 'Choose a pickup date.'
                : DateUtils.dateOnly(date!)
                        .isBefore(DateUtils.dateOnly(DateTime.now()))
                ? 'Choose today or a future date.'
                : null,
            builder: (field) => field.hasError
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),

          // Freight Offered Field (Mandatory)
          AppTextField(
            controller: price,
            label: 'Freight budget offer (₹) *',
            hint: 'Enter your freight budget amount (Mandatory)',
            prefixText: '₹ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _validatePrice,
          ),
          const SizedBox(height: 10),

          // Price is Negotiable Checkbox
          Container(
            decoration: BoxDecoration(
              color: isNegotiable
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNegotiable
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: CheckboxListTile(
              value: isNegotiable,
              onChanged: (val) => setState(() {
                isNegotiable = val ?? true;
                dirty = true;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text(
                'Price is negotiable',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: Text(
                isNegotiable
                    ? 'Transporters and drivers can submit counter-offers'
                    : 'Fixed budget offer — no counter-negotiations accepted',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Budget Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._quickPriceOffers.map((val) {
                  final formatted = NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 0,
                    locale: 'en_IN',
                  ).format(double.parse(val));
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(formatted, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        price.text = val;
                        dirty = true;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Special Instructions
          AppTextField(
            controller: note,
            label: 'Special transport instructions (optional)',
            hint: 'e.g. Tarpaulin required, loading dock open till 6 PM, fragile goods',
            lines: 2,
            maxLength: 1000,
          ),
        ],
      ),
    );
  }

  // ─── 5. Bottom Action & Summary Card ────────────────────────────────────────

  Widget _buildPublishCard(
    BuildContext context,
    ResourceState<LoadFormModel> state,
  ) {
    final cs = Theme.of(context).colorScheme;
    final hasRoute = pickupText.text.isNotEmpty && destinationText.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route & Spec Summary Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasRoute
                          ? '${pickupText.text} → ${destinationText.text}'
                          : 'Set Route & Specifications',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${weight.text.isEmpty ? '0' : weight.text} tonnes · ${vehicle ?? 'Any truck'} · ${price.text.isEmpty ? 'Set budget' : '₹${price.text}'} (${isNegotiable ? 'Negotiable' : 'Fixed'})',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notice
          Text(
            'Your load will be visible to verified transport operators immediately upon publishing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // Primary CTA Button
          AppButton(
            label: edit ? 'Save shipment changes' : 'Publish load to market',
            icon: edit ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
            busy: state.busy,
            onPressed: save,
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Card Section Container ─────────────────────────────────────────

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String stepNumber, title, subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 20, color: cs.primary.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Route Node Input Tile ───────────────────────────────────────────────────

enum _RouteNodeType { pickup, waypoint, destination }

class _RouteNode extends StatelessWidget {
  const _RouteNode({
    required this.nodeType,
    required this.label,
    required this.hint,
    required this.controller,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    required this.onLocationPicked,
    required this.searchPlace,
    this.validator,
  });

  final _RouteNodeType nodeType;
  final String label, hint;
  final TextEditingController controller;
  final double? latitude, longitude;
  final ValueChanged<String> onChanged;
  final ValueChanged<PickedMapLocation> onLocationPicked;
  final Future<List<PlaceSearchResult>> Function(String) searchPlace;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCoordinates = latitude != null && longitude != null;

    final (color, icon, title) = switch (nodeType) {
      _RouteNodeType.pickup => (
          const Color(0xFF2E7D32),
          Icons.arrow_upward_rounded,
          'PICKUP ORIGIN'
        ),
      _RouteNodeType.waypoint => (
          const Color(0xFFEF6C00),
          Icons.location_on_outlined,
          'UNLOAD STOP'
        ),
      _RouteNodeType.destination => (
          const Color(0xFFC62828),
          Icons.location_on_rounded,
          'FINAL DESTINATION'
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasCoordinates
              ? const Color(0xFF2E7D32).withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.7),
          width: hasCoordinates ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route Node Header
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 13),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Location Name Field & Map Pin Button in a ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  label: label,
                  hint: hint,
                  textCapitalization: TextCapitalization.words,
                  validator: validator,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: hasCoordinates
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                          : cs.primaryContainer.withValues(alpha: 0.5),
                      foregroundColor: hasCoordinates
                          ? const Color(0xFF2E7D32)
                          : cs.primary,
                      side: BorderSide(
                        color: hasCoordinates
                            ? const Color(0xFF2E7D32)
                            : cs.primary.withValues(alpha: 0.4),
                        width: hasCoordinates ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () async {
                      final selected = await showLocationPicker(
                        context,
                        title: 'Pick $label',
                        initialQuery: controller.text,
                        latitude: latitude,
                        longitude: longitude,
                        search: searchPlace,
                      );
                      if (selected != null) {
                        onLocationPicked(selected);
                      }
                    },
                    icon: Icon(
                      hasCoordinates ? Icons.check_circle : Icons.map_outlined,
                      size: 16,
                      color: hasCoordinates
                          ? const Color(0xFF2E7D32)
                          : cs.primary,
                    ),
                    label: Text(
                      hasCoordinates ? 'Pinned' : 'Pin on map',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: hasCoordinates
                            ? const Color(0xFF2E7D32)
                            : cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Added Location Mark in Green Text
          if (hasCoordinates) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Location added: (${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)})',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            FormField<bool>(
              key: ValueKey('$label-$hasCoordinates'),
              initialValue: hasCoordinates,
              validator: (_) => hasCoordinates
                  ? null
                  : 'Tap "Pin on map" to confirm location coordinates.',
              builder: (field) => field.hasError
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: cs.error),
                          const SizedBox(width: 4),
                          Text(
                            field.errorText!,
                            style: TextStyle(color: cs.error, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Schedule Date/Time Tile ─────────────────────────────────────────────────

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label, value, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.25)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Responsive Form Pair Helper ─────────────────────────────────────────────

class _FormPair extends StatelessWidget {
  const _FormPair({required this.first, required this.second});
  final Widget first, second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(children: [first, const SizedBox(height: 12), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );
}
