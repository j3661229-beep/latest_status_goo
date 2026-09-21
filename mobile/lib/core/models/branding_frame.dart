// lib/core/models/branding_frame.dart

enum FrameStyle {
  personal,
  businessClassic,
  businessModern,
  political,
  minimal;

  String get displayName {
    switch (this) {
      case FrameStyle.personal:
        return 'व्यक्तिगत (Personal)';
      case FrameStyle.businessClassic:
        return 'बिजनेस क्लासिक (Gold)';
      case FrameStyle.businessModern:
        return 'बिजनेस मॉडर्न (Dark)';
      case FrameStyle.political:
        return 'नेता / समाजसेवक';
      case FrameStyle.minimal:
        return 'साधारण (Minimal)';
    }
  }

  String get emoji {
    switch (this) {
      case FrameStyle.personal:
        return '👤';
      case FrameStyle.businessClassic:
        return '🏢';
      case FrameStyle.businessModern:
        return '💼';
      case FrameStyle.political:
        return '🚩';
      case FrameStyle.minimal:
        return '✨';
    }
  }

  static FrameStyle fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'BUSINESS_CLASSIC':
        return FrameStyle.businessClassic;
      case 'BUSINESS_MODERN':
        return FrameStyle.businessModern;
      case 'POLITICAL':
        return FrameStyle.political;
      case 'MINIMAL':
        return FrameStyle.minimal;
      default:
        return FrameStyle.personal;
    }
  }

  String toApiString() {
    switch (this) {
      case FrameStyle.personal:
        return 'PERSONAL';
      case FrameStyle.businessClassic:
        return 'BUSINESS_CLASSIC';
      case FrameStyle.businessModern:
        return 'BUSINESS_MODERN';
      case FrameStyle.political:
        return 'POLITICAL';
      case FrameStyle.minimal:
        return 'MINIMAL';
    }
  }
}

class BrandingFrameData {
  final String name;
  final String? photoUrl;
  final String? businessName;
  final String? businessPhone;
  final String? businessAddress;
  final String? businessDesignation;
  final String? businessLogo;
  final FrameStyle style;

  const BrandingFrameData({
    required this.name,
    this.photoUrl,
    this.businessName,
    this.businessPhone,
    this.businessAddress,
    this.businessDesignation,
    this.businessLogo,
    this.style = FrameStyle.personal,
  });

  BrandingFrameData copyWith({
    String? name,
    String? photoUrl,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? businessDesignation,
    String? businessLogo,
    FrameStyle? style,
  }) {
    return BrandingFrameData(
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      businessAddress: businessAddress ?? this.businessAddress,
      businessDesignation: businessDesignation ?? this.businessDesignation,
      businessLogo: businessLogo ?? this.businessLogo,
      style: style ?? this.style,
    );
  }
}
