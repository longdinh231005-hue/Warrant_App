/// Represents the authenticated user returned by the API.
///
/// Designed to be forward-compatible with a real backend:
///   • [fromJson] parses a raw Map (e.g. from Dio response).
///   • [toJson]   serialises back – useful for caching or logging.
///   • [copyWith] allows immutable updates inside the ViewModel.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.token,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;

  /// e.g. "admin" | "customer" – ready for role-based routing.
  final String role;

  /// JWT (or mock) bearer token.
  final String token;

  // ── Deserialisation ────────────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String? ?? 'customer',
      token: json['token'] as String,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'token': token,
      };

  // ── Immutable update helper ────────────────────────────────────────
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? token,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      token: token ?? this.token,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, fullName: $fullName, email: $email, role: $role)';
}
