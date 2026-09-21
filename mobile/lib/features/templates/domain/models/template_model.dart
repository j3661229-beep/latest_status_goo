// lib/features/templates/domain/models/template_model.dart
import 'package:json_annotation/json_annotation.dart';

part 'template_model.g.dart';

@JsonSerializable()
class TemplateModel {
  final String id;
  final String type; // 'IMAGE' | 'VIDEO'
  final String status;
  final String? categoryId;
  final CategoryModel? category;
  final TemplateCreatorModel? creator;

  // Multilingual
  final String? nameHi;
  final String? nameMr;
  final String? nameEn;
  final String? quoteHi;
  final String? quoteMr;
  final String? quoteEn;

  // Image
  final String? imageUrl;
  final String? imageThumbUrl;

  // Video
  final String? videoUrl;
  final String? videoThumbUrl;
  final int? videoDuration;

  // Gradient fallback
  final String? gradient;

  // Overlay zones
  final bool photoZoneEnabled;
  final double? photoZoneX;
  final double? photoZoneY;
  final double? photoZoneSize;
  final String? photoZoneShape;
  final bool nameZoneEnabled;
  final double? nameZoneX;
  final double? nameZoneY;
  final double? nameFontSize;
  final String? nameColor;
  final String? nameFont;

  // Meta
  final List<String> tags;
  final bool? isFeatured;
  final bool? isTrending;
  final bool? isPremium;
  final bool? isNew;
  final bool? isCoordinatorPick;
  final String? coordinatorNote;
  final int? useCount;
  final int? shareCount;
  final int? saveCount;
  final int? viewCount;
  final String? primaryLanguage;

  const TemplateModel({
    required this.id,
    required this.type,
    required this.status,
    this.categoryId,
    this.category,
    this.creator,
    this.nameHi,
    this.nameMr,
    this.nameEn,
    this.quoteHi,
    this.quoteMr,
    this.quoteEn,
    this.imageUrl,
    this.imageThumbUrl,
    this.videoUrl,
    this.videoThumbUrl,
    this.videoDuration,
    this.gradient,
    this.photoZoneEnabled = false,
    this.photoZoneX,
    this.photoZoneY,
    this.photoZoneSize,
    this.photoZoneShape,
    this.nameZoneEnabled = true,
    this.nameZoneX,
    this.nameZoneY,
    this.nameFontSize,
    this.nameColor,
    this.nameFont,
    this.tags = const [],
    this.isFeatured,
    this.isTrending,
    this.isPremium,
    this.isNew,
    this.isCoordinatorPick,
    this.coordinatorNote,
    this.useCount,
    this.shareCount,
    this.saveCount,
    this.viewCount,
    this.primaryLanguage,
  });

  bool get isVideo => type == 'VIDEO';
  bool get isImage => type == 'IMAGE';

  String nameFor(String lang) {
    return switch (lang) {
      'MARATHI' => nameMr ?? nameHi ?? nameEn ?? 'Unknown',
      'ENGLISH' => nameEn ?? nameHi ?? nameMr ?? 'Unknown',
      _ => nameHi ?? nameMr ?? nameEn ?? 'Unknown',
    };
  }

  String quoteFor(String lang) {
    return switch (lang) {
      'MARATHI' => quoteMr ?? quoteHi ?? quoteEn ?? '',
      'ENGLISH' => quoteEn ?? quoteHi ?? quoteMr ?? '',
      _ => quoteHi ?? quoteMr ?? quoteEn ?? '',
    };
  }

  factory TemplateModel.fromJson(Map<String, dynamic> json) => _$TemplateModelFromJson(json);
  Map<String, dynamic> toJson() => _$TemplateModelToJson(this);
}

@JsonSerializable()
class CategoryModel {
  final String id;
  final String slug;
  final String? nameHi;
  final String? nameMr;
  final String? nameEn;
  final String? emoji;
  final String? gradient;
  final int? templateCount;

  const CategoryModel({
    required this.id,
    required this.slug,
    this.nameHi,
    this.nameMr,
    this.nameEn,
    this.emoji,
    this.gradient,
    this.templateCount,
  });

  String nameFor(String lang) => switch (lang) {
    'MARATHI' => nameMr ?? nameHi ?? nameEn ?? slug,
    'ENGLISH' => nameEn ?? nameHi ?? nameMr ?? slug,
    _ => nameHi ?? nameMr ?? nameEn ?? slug,
  };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => _$CategoryModelFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryModelToJson(this);
}

@JsonSerializable()
class TemplateCreatorModel {
  final String id;
  final String name;
  final String? profilePhoto;

  const TemplateCreatorModel({
    required this.id,
    required this.name,
    this.profilePhoto,
  });

  factory TemplateCreatorModel.fromJson(Map<String, dynamic> json) => _$TemplateCreatorModelFromJson(json);
  Map<String, dynamic> toJson() => _$TemplateCreatorModelToJson(this);
}
