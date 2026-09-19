class UserModel {
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String profilePhoto;
  final String role;

  UserModel({
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
    required this.createdAt,
    required this.lastLogin,
    required this.profilePhoto,
    this.role = 'user',
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? 'User',
      email: json['email'],
      phone: json['phone'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : DateTime.now(),
      profilePhoto: json['profile_photo'] ?? 'https://api.dicebear.com/7.x/bottts/svg?seed=LegalScanner',
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin.toIso8601String(),
      'profile_photo': profilePhoto,
      'role': role,
    };
  }

  String get displayIdentifier {
    if (email != null && email!.isNotEmpty) return email!;
    if (phone != null && phone!.isNotEmpty) return phone!;
    return 'Registered User';
  }

  UserModel copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? profilePhoto,
    String? role,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      role: role ?? this.role,
    );
  }
}
