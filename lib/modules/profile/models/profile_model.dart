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
    this.gender,
    String verificationStatus = 'pending',
  }) : _verificationStatus = verificationStatus;

  final String id, name, phone;
  final String _verificationStatus;
  final UserRole role;
  final String? photoPath, address, companyName, gender;

  /// All accounts (drivers and customers) are immediately verified upon login.
  String get verificationStatus => 'verified';

  /// Account data needed before a signed-in user can use the marketplace.
  ///
  /// Required: Name, validated Indian mobile phone, and residential/pickup address.
  bool get needsSetup =>
      name.trim().length < 2 ||
      !isValidIndianMobile(phone) ||
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
    String? parsedGender = json['gender'];
    if (parsedGender == null &&
        json['company_name'] != null &&
        json['company_name'].toString().startsWith('Gender: ')) {
      parsedGender =
          json['company_name'].toString().replaceFirst('Gender: ', '');
    }
    return ProfileModel(
      id: json['id'],
      name: json['name'],
      role: parsedRole,
      phone: json['phone'] ?? '',
      photoPath: json['photo_path'],
      address: json['address'],
      companyName: json['company_name'],
      gender: parsedGender,
      verificationStatus: 'verified',
    );
  }

  ProfileModel copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? phone,
    String? photoPath,
    String? address,
    String? companyName,
    String? gender,
    String? verificationStatus,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
      address: address ?? this.address,
      companyName: companyName ?? this.companyName,
      gender: gender ?? this.gender,
      verificationStatus: verificationStatus ?? _verificationStatus,
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
    gender,
    verificationStatus,
  ];
}
