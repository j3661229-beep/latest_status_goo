// lib/core/services/status_export_service.dart
//
// Shared capture / save-to-gallery / share helpers used by Home and the
// template preview screen.
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';

enum GallerySaveResult { saved, permissionDenied, failed }

class StatusExportService {
  StatusExportService._();

  /// Captures the [RepaintBoundary] behind [key] so the output width is always
  /// [AppConstants.frameWidth] pixels (consistent export size on every device).
  static Future<Uint8List?> capture(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.width <= 0) return null;
      final pixelRatio = (AppConstants.frameWidth / boundary.size.width).clamp(1.0, 6.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('StatusExportService.capture error: $e');
      return null;
    }
  }

  /// Requests the minimum permission needed to add an image to the gallery.
  /// - Android 10+ (API 29+): MediaStore insert needs no permission.
  /// - Android 9 and below: WRITE_EXTERNAL_STORAGE (Permission.storage).
  /// - iOS: add-only photo library access.
  static Future<bool> _ensureSavePermission() async {
    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk >= 29) return true;
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  static Future<GallerySaveResult> saveToGallery(Uint8List pngBytes) async {
    try {
      if (!await _ensureSavePermission()) return GallerySaveResult.permissionDenied;
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: 'status_go_${DateTime.now().millisecondsSinceEpoch}',
      );
      final ok = result is Map && (result['isSuccess'] == true);
      return ok ? GallerySaveResult.saved : GallerySaveResult.failed;
    } catch (e) {
      debugPrint('StatusExportService.saveToGallery error: $e');
      return GallerySaveResult.failed;
    }
  }

  /// Shows the standard SnackBar for a save result (with "Open settings" on denial).
  static void showSaveResult(BuildContext context, GallerySaveResult result) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final success = result == GallerySaveResult.saved;
    final denied = result == GallerySaveResult.permissionDenied;
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'फोटो गैलरी में सेव हो गई! 📥'
                    : denied
                        ? 'गैलरी में सेव करने की अनुमति नहीं मिली'
                        : 'सेव नहीं हो सकी। कृपया दोबारा कोशिश करें।',
                style: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: denied
            ? SnackBarAction(
                label: 'सेटिंग्स खोलें',
                textColor: Colors.white,
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
  }

  /// Shares PNG bytes via the system share sheet. Returns the backend
  /// SharePlatform value for analytics, or null if the user dismissed it.
  static Future<String?> sharePng(Uint8List pngBytes, {String? text}) async {
    final xfile = XFile.fromData(
      pngBytes,
      mimeType: 'image/png',
      name: 'status_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final result = await Share.shareXFiles([xfile], text: text ?? 'Status Go ऐप से भेजा गया 📲');
    if (result.status == ShareResultStatus.dismissed) return null;
    return _platformFromShareResult(result.raw);
  }

  /// Maps the share target (Android package name, when available) to the
  /// backend `SharePlatform` enum.
  static String _platformFromShareResult(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('whatsapp')) return 'WHATSAPP_STATUS';
    if (r.contains('instagram')) return 'INSTAGRAM_STORIES';
    if (r.contains('facebook')) return 'FACEBOOK';
    return 'OTHER';
  }
}
