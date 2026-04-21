// lib/features/auth/domain/models/user_model.dart
// ignore_for_file: invalid_annotation_target
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? displayName;
  final String? profilePhoto;
  final String? customPhotoUrl;
  final String language;
  final String plan;
  final String role;
  final int streakCount;
  final int totalShares;
  final int totalSaves;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.displayName,
    this.profilePhoto,
    this.customPhotoUrl,
    this.language = 'HINDI',
    this.plan = 'FREE',
    this.role = 'USER',
    this.streakCount = 0,
    this.totalShares = 0,
    this.totalSaves = 0,
  });

  bool get isPremium => plan == 'PREMIUM' || plan == 'ANNUAL';
  bool get isCreator => role == 'CREATOR';
  bool get isAdmin => role == 'MANAGER' || role == 'SUPER_ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    String? displayName,
    String? customPhotoUrl,
    String? language,
    String? plan,
    int? streakCount,
    int? totalShares,
    int? totalSaves,
  }) {
    return UserModel(
      id: id, name: name, email: email,
      profilePhoto: profilePhoto,
      displayName: displayName ?? this.displayName,
      customPhotoUrl: customPhotoUrl ?? this.customPhotoUrl,
      language: language ?? this.language,
      plan: plan ?? this.plan,
      role: role,
      streakCount: streakCount ?? this.streakCount,
      totalShares: totalShares ?? this.totalShares,
      totalSaves: totalSaves ?? this.totalSaves,
    );
  }
}
