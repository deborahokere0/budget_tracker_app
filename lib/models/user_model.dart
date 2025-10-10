class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String username;
  final String incomeType; // 'fixed', 'variable', 'hybrid'
  final DateTime createdAt;
  final String? profileImageUrl;
  final double? monthlyIncome;
  final double? targetSavings;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.username,
    required this.incomeType,
    required this.createdAt,
    this.profileImageUrl,
    this.monthlyIncome,
    this.targetSavings,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'username': username,
      'incomeType': incomeType,
      'createdAt': createdAt.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'monthlyIncome': monthlyIncome,
      'targetSavings': targetSavings,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      username: map['username'] ?? '',
      incomeType: map['incomeType'] ?? 'fixed',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      profileImageUrl: map['profileImageUrl'],
      monthlyIncome: map['monthlyIncome']?.toDouble(),
      targetSavings: map['targetSavings']?.toDouble(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? username,
    String? incomeType,
    DateTime? createdAt,
    String? profileImageUrl,
    double? monthlyIncome,
    double? targetSavings,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      incomeType: incomeType ?? this.incomeType,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      targetSavings: targetSavings ?? this.targetSavings,
    );
  }
}