import 'package:equatable/equatable.dart';

class FinanceEntryModel extends Equatable {
  const FinanceEntryModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.occurredOn,
    this.note = '',
  });
  final String id, type, category, note;
  final double amount;
  final DateTime occurredOn;
  factory FinanceEntryModel.fromJson(Map<String, dynamic> json) =>
      FinanceEntryModel(
        id: json['id'],
        type: json['entry_type'],
        category: json['category'],
        amount: (json['amount'] as num).toDouble(),
        occurredOn: DateTime.parse(json['occurred_on']),
        note: json['note'] ?? '',
      );
  @override
  List<Object?> get props => [id, type, category, amount, occurredOn, note];
}

class FinanceEntryDraft {
  const FinanceEntryDraft({
    required this.type,
    required this.category,
    required this.amount,
    required this.occurredOn,
    this.note = '',
  });
  final String type, category, note;
  final double amount;
  final DateTime occurredOn;
  Map<String, dynamic> toJson() => {
    'entry_type': type,
    'category': category,
    'amount': amount,
    'occurred_on': occurredOn.toIso8601String().split('T').first,
    'note': note.trim(),
  };
}
