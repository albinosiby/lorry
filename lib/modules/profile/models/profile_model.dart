import 'package:equatable/equatable.dart';

enum UserRole {
  shipper,
  driver;

  String get label => this == shipper ? 'Shipper' : 'Transporter / Driver';
}

class ProfileModel extends Equatable {
  const ProfileModel({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
  });
  final String id, name, phone;
  final UserRole role;
  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    id: json['id'],
    name: json['name'],
    role: UserRole.values.byName(json['role']),
    phone: json['phone'] ?? '',
  );
  @override
  List<Object?> get props => [id, name, role, phone];
}
