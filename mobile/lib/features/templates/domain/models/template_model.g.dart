// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TemplateModel _$TemplateModelFromJson(Map<String, dynamic> json) =>
    TemplateModel(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      categoryId: json['categoryId'] as String?,
      category: json['category'] == null
          ? null
          : CategoryModel.fromJson(json['category'] as Map<String, dynamic>),
      creator: json['creator'] == null
          ? null
          : TemplateCreatorModel.fromJson(
              json['creator'] as Map<String, dynamic>),
      nameHi: json['nameHi'] as String?,
      nameMr: json['nameMr'] as String?,
      nameEn: json['nameEn'] as String?,
      quoteHi: json['quoteHi'] as String?,
      quoteMr: json['quoteMr'] as String?,
      quoteEn: json['quoteEn'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imageThumbUrl: json['imageThumbUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      videoThumbUrl: json['videoThumbUrl'] as String?,
      videoDuration: (json['videoDuration'] as num?)?.toInt(),
      gradient: json['gradient'] as String?,
      photoZoneEnabled: json['photoZoneEnabled'] as bool? ?? false,
      photoZoneX: (json['photoZoneX'] as num?)?.toDouble(),
      photoZoneY: (json['photoZoneY'] as num?)?.toDouble(),
      photoZoneSize: (json['photoZoneSize'] as num?)?.toDouble(),
      photoZoneShape: json['photoZoneShape'] as String?,
      nameZoneEnabled: json['nameZoneEnabled'] as bool? ?? true,
      nameZoneX: (json['nameZoneX'] as num?)?.toDouble(),
      nameZoneY: (json['nameZoneY'] as num?)?.toDouble(),
      nameFontSize: (json['nameFontSize'] as num?)?.toDouble(),
      nameColor: json['nameColor'] as String?,
      nameFont: json['nameFont'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      isFeatured: json['isFeatured'] as bool?,
      isTrending: json['isTrending'] as bool?,
      isPremium: json['isPremium'] as bool?,
      isNew: json['isNew'] as bool?,
      isCoordinatorPick: json['isCoordinatorPick'] as bool?,
      coordinatorNote: json['coordinatorNote'] as String?,
      useCount: (json['useCount'] as num?)?.toInt(),
      shareCount: (json['shareCount'] as num?)?.toInt(),
      saveCount: (json['saveCount'] as num?)?.toInt(),
      viewCount: (json['viewCount'] as num?)?.toInt(),
      primaryLanguage: json['primaryLanguage'] as String?,
    );

Map<String, dynamic> _$TemplateModelToJson(TemplateModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'status': instance.status,
      'categoryId': instance.categoryId,
      'category': instance.category,
      'creator': instance.creator,
      'nameHi': instance.nameHi,
      'nameMr': instance.nameMr,
      'nameEn': instance.nameEn,
      'quoteHi': instance.quoteHi,
      'quoteMr': instance.quoteMr,
      'quoteEn': instance.quoteEn,
      'imageUrl': instance.imageUrl,
      'imageThumbUrl': instance.imageThumbUrl,
      'videoUrl': instance.videoUrl,
      'videoThumbUrl': instance.videoThumbUrl,
      'videoDuration': instance.videoDuration,
      'gradient': instance.gradient,
      'photoZoneEnabled': instance.photoZoneEnabled,
      'photoZoneX': instance.photoZoneX,
      'photoZoneY': instance.photoZoneY,
      'photoZoneSize': instance.photoZoneSize,
      'photoZoneShape': instance.photoZoneShape,
      'nameZoneEnabled': instance.nameZoneEnabled,
      'nameZoneX': instance.nameZoneX,
      'nameZoneY': instance.nameZoneY,
      'nameFontSize': instance.nameFontSize,
      'nameColor': instance.nameColor,
      'nameFont': instance.nameFont,
      'tags': instance.tags,
      'isFeatured': instance.isFeatured,
      'isTrending': instance.isTrending,
      'isPremium': instance.isPremium,
      'isNew': instance.isNew,
      'isCoordinatorPick': instance.isCoordinatorPick,
      'coordinatorNote': instance.coordinatorNote,
      'useCount': instance.useCount,
      'shareCount': instance.shareCount,
      'saveCount': instance.saveCount,
      'viewCount': instance.viewCount,
      'primaryLanguage': instance.primaryLanguage,
    };

CategoryModel _$CategoryModelFromJson(Map<String, dynamic> json) =>
    CategoryModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nameHi: json['nameHi'] as String?,
      nameMr: json['nameMr'] as String?,
      nameEn: json['nameEn'] as String?,
      emoji: json['emoji'] as String?,
      gradient: json['gradient'] as String?,
      templateCount: (json['templateCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CategoryModelToJson(CategoryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'nameHi': instance.nameHi,
      'nameMr': instance.nameMr,
      'nameEn': instance.nameEn,
      'emoji': instance.emoji,
      'gradient': instance.gradient,
      'templateCount': instance.templateCount,
    };

TemplateCreatorModel _$TemplateCreatorModelFromJson(
        Map<String, dynamic> json) =>
    TemplateCreatorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      profilePhoto: json['profilePhoto'] as String?,
    );

Map<String, dynamic> _$TemplateCreatorModelToJson(
        TemplateCreatorModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'profilePhoto': instance.profilePhoto,
    };
