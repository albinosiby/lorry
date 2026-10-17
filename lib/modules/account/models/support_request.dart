class SupportRequest {
  const SupportRequest({
    required this.name,
    required this.email,
    required this.issue,
    required this.userId,
    required this.userRole,
    required this.phone,
  });

  final String name;
  final String email;
  final String issue;
  final String userId;
  final String userRole;
  final String phone;
}
