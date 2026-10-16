import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../loads/models/load_model.dart';

class TruckLengthInput extends StatefulWidget {
  const TruckLengthInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAny = false,
    this.label = 'Vehicle deck length',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAny;
  final String label;

  @override
  State<TruckLengthInput> createState() => _TruckLengthInputState();
}

class _TruckLengthInputState extends State<TruckLengthInput> {
  final custom = TextEditingController();
  String? selection;
  String? lastEmitted;

  void syncValue() {
    lastEmitted = widget.value;
    final number = double.tryParse(widget.value ?? '');
    final value = number == null ? null : feetValue(number);
    selection = value == null
        ? (widget.allowAny ? 'any' : null)
        : vehicleLengthOptions.contains(value)
        ? value
        : 'custom';
    custom.text = selection == 'custom' ? value! : '';
  }

  @override
  void initState() {
    super.initState();
    syncValue();
  }

  @override
  void didUpdateWidget(covariant TruckLengthInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != lastEmitted) {
      syncValue();
    }
  }

  void emit(String? value) {
    lastEmitted = value;
    widget.onChanged(value);
  }

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey(selection),
        initialValue: selection,
        isExpanded: true,
        decoration: localizedDecoration(
          context,
          InputDecoration(labelText: widget.label),
        ),
        items: [
          if (widget.allowAny)
            const DropdownMenuItem(
              value: 'any',
              child: LocalizedText('Any length'),
            ),
          ...vehicleLengthOptions.map(
            (value) => DropdownMenuItem(
              value: value,
              child: LocalizedText('$value ft'),
            ),
          ),
          const DropdownMenuItem(
            value: 'custom',
            child: LocalizedText('Custom length'),
          ),
        ],
        validator: (value) => value == null ? 'Choose a truck length' : null,
        onChanged: (value) {
          setState(() => selection = value);
          emit(
            value == 'any'
                ? null
                : value == 'custom'
                ? custom.text
                : value,
          );
        },
      ),
      if (selection == 'custom') ...[
        const SizedBox(height: 12),
        TextFormField(
          errorBuilder: (context, message) => LocalizedText(message),
          controller: custom,
          decoration: localizedDecoration(
            context,
            InputDecoration(
              labelText: 'Custom length (ft)',
              hintText: 'For example, 17.5',
              helperText: 'Greater than 0, up to 80 ft; max. 2 decimal places',
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: emit,
          validator: (value) {
            final text = (value ?? '').trim();
            final number = double.tryParse(text);
            return number == null ||
                    !number.isFinite ||
                    number <= 0 ||
                    number > 80 ||
                    !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)
                ? 'Enter a length greater than 0 and up to 80 ft (max. 2 decimals)'
                : null;
          },
        ),
      ],
    ],
  );
}
