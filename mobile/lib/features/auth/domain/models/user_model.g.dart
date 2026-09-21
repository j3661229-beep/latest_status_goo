// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      displayName: json['displayName'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      customPhotoUrl: json['customPhotoUrl'] as String?,
      language: json['language'] as String? ?? 'HINDI',
      plan: json['plan'] as String? ?? 'FREE',
      role: json['role'] as String? ?? 'USER',
      streakCount: (json['streakCount'] as num?)?.toInt() ?? 0,
      totalShares: (json['totalShares'] as num?)?.toInt() ?? 0,
      totalSaves: (json['totalSaves'] as num?)?.toInt() ?? 0,
      state: json['state'] as String?,
      region: json['region'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      businessName: json['businessName'] as String?,
      businessPhone: json['businessPhone'] as String?,
      businessAddress: json['businessAddress'] as String?,
      businessDesignation: json['businessDesignation'] as String?,
      businessLogo: json['businessLogo'] as String?,
      frameType: json['frameType'] as String? ?? 'personal',
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'displayName': instance.displayName,
      'profilePhoto': instance.profilePhoto,
      'customPhotoUrl': instance.customPhotoUrl,
      'language': instance.language,
      'plan': instance.plan,
      'role': instance.role,
      'streakCount': instance.streakCount,
      'totalShares': instance.totalShares,
      'totalSaves': instance.totalSaves,
      'state': instance.state,
      'region': instance.region,
      'onboardingCompleted': instance.onboardingCompleted,
      'businessName': instance.businessName,
      'businessPhone': instance.businessPhone,
      'businessAddress': instance.businessAddress,
      'businessDesignation': instance.businessDesignation,
      'businessLogo': instance.businessLogo,
      'frameType': instance.frameType,
    };

