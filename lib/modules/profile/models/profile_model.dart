import 'package:equatable/equatable.dart';

enum UserRole {
  shipper,
  driver;

  /// User-facing marketplace name. The persisted database role remains
  /// `shipper` for backwards compatibility with existing accounts and RPCs.
  String get label => this == shipper ? 'Customer' : 'Transporter / Driver';
}

class ProfileModel extends Equatable {
  const ProfileModel({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.photoPath,
    this.address,
    this.companyName,
    String verificationStatus = 'pending',
  }) : _verificationStatus = verificationStatus;

  final String id, name, phone;
  final String _verificationStatus;
  final UserRole role;
  final String? photoPath, address, companyName;

  /// All accounts (drivers and customers) are immediately verified upon login.
  String get verificationStatus => 'verified';

  /// Account data needed before a signed-in user can use the marketplace.
  ///
  /// Company information is optional, and verification is an approval process,
  /// so neither should prevent a user from entering the app.
  bool get needsSetup =>
      name.trim().length < 2 ||
      !isValidIndianMobile(phone) ||
      (photoPath?.trim().isEmpty ?? true) ||
      (address?.trim().isEmpty ?? true);

  static bool isValidIndianMobile(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^(91)?[6-9][0-9]{9}$').hasMatch(digits);
  }

  /// Stores every accepted local or international entry in one call-ready form.
  static String normalizeIndianMobile(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return '+91$digits';
  }

  static String indianMobileForInput(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final parsedRole = UserRole.values.byName(json['role']);
    return ProfileModel(
      id: json['id'],
      name: json['name'],
      role: parsedRole,
      phone: json['phone'] ?? '',
      photoPath: json['photo_path'],
      address: json['address'],
      companyName: json['company_name'],
      verificationStatus: 'verified',
    );
  }
  @override
  List<Object?> get props => [
    id,
    name,
    role,
    phone,
    photoPath,
    address,
    companyName,
    verificationStatus,
  ];
}
