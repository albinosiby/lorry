import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.password = false,
    this.keyboardType,
    this.lines = 1,
    this.hint,
    this.maxLength,
    this.onChanged,
    this.prefixText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool password;
  final TextInputType? keyboardType;
  final int lines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: widget.password && hidden,
      keyboardType: widget.keyboardType,
      maxLines: widget.lines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      autocorrect: !widget.password,
      enableSuggestions: !widget.password,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixText: widget.prefixText,
        suffixIcon: widget.password
            ? IconButton(
                tooltip: hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
    ),
  );
}

abstract final class Validators {
  static String? required(String? v) =>
      v == null || v.trim().isEmpty ? 'This field is required.' : null;
  static String? email(String? v) =>
      v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
      ? 'Enter a valid email address.'
      : null;
  static String? password(String? v) =>
      v == null || v.length < 8 ? 'Use at least 8 characters.' : null;
  static String? name(String? v) =>
      v == null || v.trim().length < 2 ? 'Enter at least 2 characters.' : null;
}
