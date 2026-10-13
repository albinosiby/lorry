import 'package:flutter/material.dart';

void showNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> cancellationReason(BuildContext context) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel booking?'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Tell the other party why',
          ),
          validator: (v) =>
              (v?.trim().length ?? 0) < 3 ? 'Please enter a reason.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep booking'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Cancel booking'),
        ),
      ],
    ),
  );
  // The dialog route finishes its closing animation before disposing its field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}
