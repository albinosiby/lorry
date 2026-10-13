import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:lorry_link/design_system/design_system.dart';
import 'package:lorry_link/core/state/resource_cubit.dart';
import '../cubit/load_form_cubit.dart';
import '../models/load_model.dart';
import '../models/load_screen_models.dart';

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
  final cargo = TextEditingController(), price = TextEditingController();
  String draftId = const Uuid().v4();
  String? pickup, destination, vehicle;
  String contact = 'after_acceptance';
  DateTime? date;
  bool populated = false, dirty = false;
  bool get edit => widget.id != null;
  @override
  void dispose() {
    pickupText.dispose();
    destinationText.dispose();
    cargo.dispose();
    price.dispose();
    super.dispose();
  }

  void populate(LoadFormModel? m) {
    if (edit && !populated && m?.load != null) {
      final l = m!.load!;
      pickup = l.pickupLabel;
      destination = l.destinationLabel;
      pickupText.text = l.pickupLabel;
      destinationText.text = l.destinationLabel;
      vehicle = l.vehicle;
      cargo.text = l.cargo;
      price.text = l.price?.toStringAsFixed(2) ?? '';
      date = l.pickupDate;
      contact = l.contactPreference;
      populated = true;
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    pickup = canonicalLocation(pickupText.text);
    destination = canonicalLocation(destinationText.text);
    final ok = await context.read<LoadFormCubit>().save(
      LoadDraft(
        id: widget.id ?? draftId,
        pickup: pickup!,
        destination: destination!,
        cargo: cargo.text,
        vehicle: vehicle!,
        date: date!,
        price: double.tryParse(price.text),
        contactPreference: contact,
      ),
      edit: edit,
    );
    if (ok && mounted) {
      setState(() => dirty = false);
      if (edit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      } else {
        final published = draftId;
        form.currentState?.reset();
        cargo.clear();
        price.clear();
        setState(() {
          draftId = const Uuid().v4();
          pickup = null;
          destination = null;
          pickupText.clear();
          destinationText.clear();
          vehicle = null;
          date = null;
          contact = 'after_acceptance';
          dirty = false;
        });
        context.push('/loads/$published');
      }
    }
  }

  Widget select(
    String label,
    List<String> values,
    String? value,
    ValueChanged<String?> changed, {
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$draftId-$populated'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      validator: validator ?? Validators.required,
      onChanged: (v) {
        setState(() {
          changed(v);
          dirty = true;
        });
      },
    ),
  );

  String? canonicalLocation(String? value) {
    final input = value?.trim();
    return input == null || input.isEmpty ? null : placeLabel(input);
  }

  String? validateLocation(String? value) => canonicalLocation(value) == null
      ? 'Enter a pickup or destination place.'
      : null;

  Widget locationInput(
    String label,
    TextEditingController controller,
    ValueChanged<String> changed, {
    String? Function(String?)? validator,
  }) => AppTextField(
    controller: controller,
    label: label,
    hint: 'e.g. Mumbai',
    textCapitalization: TextCapitalization.words,
    validator: validator ?? validateLocation,
    onChanged: changed,
  );
  @override
  Widget build(BuildContext context) {
    final body = PageBody(
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
                : const Center(child: CircularProgressIndicator());
          }
          return Form(
            key: form,
            onChanged: () {
              if (!dirty) setState(() => dirty = true);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeading(
                  'Make your next connection',
                  edit ? 'Edit your load' : 'What are we moving?',
                  edit
                      ? 'Update the details of your open listing.'
                      : 'A few details are all it takes to get started.',
                ),
                _section('01', 'The route'),
                locationInput(
                  'Pickup city',
                  pickupText,
                  (v) => setState(() => pickup = canonicalLocation(v)),
                ),
                locationInput(
                  'Destination city',
                  destinationText,
                  (v) => setState(() => destination = canonicalLocation(v)),
                  validator: (v) {
                    final location = canonicalLocation(v);
                    if (location == null) return validateLocation(v);
                    return location == pickup
                        ? 'Choose a different destination.'
                        : null;
                  },
                ),
                _section('02', 'The cargo'),
                AppTextField(
                  controller: cargo,
                  label: 'Cargo description',
                  hint: 'e.g. Packaged textiles, 4 tonnes',
                  lines: 3,
                  maxLength: 2000,
                  validator: (v) => (v?.trim().length ?? 0) < 3
                      ? 'Describe your cargo.'
                      : null,
                ),
                select(
                  'Required vehicle',
                  vehicleTypes,
                  vehicle,
                  (v) => vehicle = v,
                ),
                _section('03', 'Schedule & details'),
                FormField<DateTime>(
                  key: ValueKey('date-$draftId-$populated'),
                  validator: (_) => date == null
                      ? 'Choose a pickup date.'
                      : DateUtils.dateOnly(
                          date!,
                        ).isBefore(DateUtils.dateOnly(DateTime.now()))
                      ? 'Choose today or a future date.'
                      : null,
                  builder: (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final today = DateUtils.dateOnly(DateTime.now());
                        final chosen = await showDatePicker(
                          context: context,
                          initialDate: date == null || date!.isBefore(today)
                              ? today
                              : date!,
                          firstDate: today,
                          lastDate: today.add(const Duration(days: 730)),
                        );
                        if (chosen != null) {
                          setState(() {
                            date = chosen;
                            dirty = true;
                          });
                          field.didChange(chosen);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Pickup date',
                          errorText: field.errorText,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          date == null
                              ? 'Select a date'
                              : DateFormat('EEE, d MMM yyyy').format(date!),
                        ),
                      ),
                    ),
                  ),
                ),
                AppTextField(
                  controller: price,
                  label: 'Expected price in INR (optional)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final number = double.tryParse(v);
                    return number == null ||
                            !number.isFinite ||
                            number < 0 ||
                            number > 9999999999
                        ? 'Enter a valid, nonnegative amount.'
                        : null;
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: contact,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Contact preference',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'after_acceptance',
                      child: Text('Share phone after acceptance'),
                    ),
                    DropdownMenuItem(
                      value: 'phone',
                      child: Text('Allow phone contact before booking'),
                    ),
                  ],
                  onChanged: (v) => setState(() => contact = v!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your phone number comes from your profile. Booking decisions always happen in the app.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: edit ? 'Save changes' : 'Publish load',
                  icon: edit ? Icons.check : Icons.arrow_forward,
                  busy: state.busy,
                  onPressed: save,
                ),
              ],
            ),
          );
        },
      ),
    );
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            await confirmAction(
              context,
              'Discard changes?',
              'Your unsaved load details will be lost.',
              confirm: 'Discard',
            ) &&
            context.mounted) {
          setState(() => dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
        }
      },
      child: edit
          ? Scaffold(
              appBar: AppBar(title: const Text('Edit load')),
              body: body,
            )
          : body,
    );
  }

  Widget _section(String number, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 20, top: 8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            number,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    ),
  );
}
