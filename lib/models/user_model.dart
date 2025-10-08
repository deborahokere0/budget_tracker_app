// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String username;
  final String incomeType; // 'fixed', 'variable', or 'hybrid'
  final DateTime createdAt;
  final double? monthlyIncome;
  final double? targetSavings;
  final String? profileImageUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.username,
    required this.incomeType,
    required this.createdAt,
    this.monthlyIncome,
    this.targetSavings,
    this.profileImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'username': username,
      'incomeType': incomeType,
      'createdAt': createdAt.toIso8601String(),
      'monthlyIncome': monthlyIncome,
      'targetSavings': targetSavings,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      username: map['username'] ?? '',
      incomeType: map['incomeType'] ?? 'fixed',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      monthlyIncome: map['monthlyIncome']?.toDouble(),
      targetSavings: map['targetSavings']?.toDouble(),
      profileImageUrl: map['profileImageUrl'],
    );
  }
}