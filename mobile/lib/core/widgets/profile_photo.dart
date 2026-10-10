// lib/core/widgets/profile_photo.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../auth/session_store.dart';

/// Builds an [ImageProvider] from either a remote URL (http/https) or a local
/// file path. Returns null if [source] is empty or the local file is missing.
ImageProvider? photoImageProvider(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  if (SessionStore.isRemoteUrl(source)) return CachedNetworkImageProvider(source);
  final file = File(source);
  if (file.existsSync()) return FileImage(file);
  return null;
}

/// Picks the first usable photo among [sources] (e.g. local path, then URL).
ImageProvider? firstPhotoImageProvider(Iterable<String?> sources) {
  for (final s in sources) {
    final provider = photoImageProvider(s);
    if (provider != null) return provider;
  }
  return null;
}

/// The current user's photo: locally picked file first, then the uploaded URL.
ImageProvider? currentUserPhotoProvider({String? serverPhoto}) {
  final session = SessionStore.instance;
  return firstPhotoImageProvider([session.localPhotoPath, session.profilePhotoUrl, serverPhoto]);
}

/// Circular avatar that renders a photo from a URL or local path, with a
/// fallback child (initial / icon) when no photo is available.
class ProfilePhotoAvatar extends StatelessWidget {
  final ImageProvider? image;
  final double radius;
  final Color backgroundColor;
  final Widget fallback;

  const ProfilePhotoAvatar({
    super.key,
    required this.image,
    required this.radius,
    required this.backgroundColor,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final img = image;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: img,
      onBackgroundImageError: img == null ? null : (_, __) {},
      child: img == null ? fallback : null,
    );
  }
}
