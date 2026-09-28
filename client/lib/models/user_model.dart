class UserModel {
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String profilePhoto;
  final String role;
  final DateTime? dateOfBirth;
  final String? preferredLanguage;
  final DateTime? termsAcceptedAt;
  final String? termsVersion;

  UserModel({
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
    required this.createdAt,
    required this.lastLogin,
    required this.profilePhoto,
    this.role = 'user',
    this.dateOfBirth,
    this.preferredLanguage,
    this.termsAcceptedAt,
    this.termsVersion,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? 'User',
      email: json['email'],
      phone: json['phone'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      lastLogin: json['last_login'] != null ? DateTime.tryParse(json['last_login'].toString()) ?? DateTime.now() : DateTime.now(),
      profilePhoto: json['profile_photo'] ?? 'https://api.dicebear.com/7.x/bottts/svg?seed=LegalScanner',
      role: json['role'] ?? 'user',
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth'].toString()) : null,
      preferredLanguage: json['preferredLanguage'],
      termsAcceptedAt: json['termsAcceptedAt'] != null ? DateTime.tryParse(json['termsAcceptedAt'].toString()) : null,
      termsVersion: json['termsVersion'],
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
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (termsAcceptedAt != null) 'termsAcceptedAt': termsAcceptedAt!.toIso8601String(),
      if (termsVersion != null) 'termsVersion': termsVersion,
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
    DateTime? dateOfBirth,
    String? preferredLanguage,
    DateTime? termsAcceptedAt,
    String? termsVersion,
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      termsVersion: termsVersion ?? this.termsVersion,
    );
  }
}
