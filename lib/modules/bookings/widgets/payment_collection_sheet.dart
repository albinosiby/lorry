import 'package:lorry_link/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../design_system/design_system.dart';
import '../cubit/booking_details_cubit.dart';
import '../models/booking_model.dart';

Future<void> collectBookingPayment(
  BuildContext context,
  BookingModel booking,
) async {
  final value = await showModalBottomSheet<({double amount, double? freight})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentSheet(booking: booking),
  );
  if (value == null || !context.mounted) return;
  await context.read<BookingDetailsCubit>().recordPayment(
    booking.id,
    value.amount,
    agreedFreight: value.freight,
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.booking});
  final BookingModel booking;
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final freight = TextEditingController();
  @override
  void dispose() {
    amount.dispose();
    freight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedText(
              'Record payment collected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LocalizedText(
              'Collected so far: ₹${widget.booking.amountCollected.toStringAsFixed(2)}',
            ),
            if (widget.booking.balance != null)
              LocalizedText(
                'Remaining balance: ₹${widget.booking.balance!.toStringAsFixed(2)}',
              ),
            const LocalizedText(
              'Record only money actually received. Partial collection is allowed. This does not charge the customer online.',
            ),
            const SizedBox(height: 16),
            if (widget.booking.freight == null)
              AppTextField(
                controller: freight,
                label: 'Agreed total freight (₹)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {final n = double.tryParse(value ?? ''); return n == null || !n.isFinite || n <= 0 ? 'Enter the agreed total freight.' : null;},
              ),
            AppTextField(
              controller: amount,
              label: 'New amount collected (₹)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {final n = double.tryParse(value ?? ''); final remaining = widget.booking.balance ?? ((double.tryParse(freight.text) ?? 0) - widget.booking.amountCollected); return n == null || !n.isFinite || n <= 0 ? 'Enter a valid amount.' : n > remaining ? 'Amount exceeds the remaining balance.' : null;},
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Record collection & add income',
              icon: Icons.payments_outlined,
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, (
                    amount: double.parse(amount.text),
                    freight: double.tryParse(freight.text),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
