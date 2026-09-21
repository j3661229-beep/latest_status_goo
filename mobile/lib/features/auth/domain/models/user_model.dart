// lib/features/auth/domain/models/user_model.dart
// ignore_for_file: invalid_annotation_target
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? profilePhoto;
  final String? customPhotoUrl;
  final String language;
  final String plan;
  final String role;
  final int streakCount;
  final int totalShares;
  final int totalSaves;
  // Location for personalised feed
  final String? state;
  final String? region;
  final bool onboardingCompleted;

  // Business Branding & Frame Customization (Crafto Suite)
  final String? businessName;
  final String? businessPhone;
  final String? businessAddress;
  final String? businessDesignation;
  final String? businessLogo;
  final String frameType;

  const UserModel({
    required this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.profilePhoto,
    this.customPhotoUrl,
    this.language = 'HINDI',
    this.plan = 'FREE',
    this.role = 'USER',
    this.streakCount = 0,
    this.totalShares = 0,
    this.totalSaves = 0,
    this.state,
    this.region,
    this.onboardingCompleted = false,
    this.businessName,
    this.businessPhone,
    this.businessAddress,
    this.businessDesignation,
    this.businessLogo,
    this.frameType = 'personal',
  });

  bool get isPremium => plan == 'PREMIUM' || plan == 'ANNUAL';
  bool get isCreator => role == 'CREATOR';
  bool get isAdmin => role == 'MANAGER' || role == 'SUPER_ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    String? name,
    String? phoneNumber,
    String? profilePhoto,
    String? displayName,
    String? customPhotoUrl,
    String? language,
    String? plan,
    int? streakCount,
    int? totalShares,
    int? totalSaves,
    String? state,
    String? region,
    bool? onboardingCompleted,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? businessDesignation,
    String? businessLogo,
    String? frameType,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      displayName: displayName ?? this.displayName,
      customPhotoUrl: customPhotoUrl ?? this.customPhotoUrl,
      language: language ?? this.language,
      plan: plan ?? this.plan,
      role: role,
      streakCount: streakCount ?? this.streakCount,
      totalShares: totalShares ?? this.totalShares,
      totalSaves: totalSaves ?? this.totalSaves,
      state: state ?? this.state,
      region: region ?? this.region,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      businessAddress: businessAddress ?? this.businessAddress,
      businessDesignation: businessDesignation ?? this.businessDesignation,
      businessLogo: businessLogo ?? this.businessLogo,
      frameType: frameType ?? this.frameType,
    );
  }
}
