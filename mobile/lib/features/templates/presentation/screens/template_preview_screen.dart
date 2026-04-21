// lib/features/templates/presentation/screens/template_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';

class TemplatePreviewScreen extends ConsumerStatefulWidget {
  final String templateId;
  const TemplatePreviewScreen({super.key, required this.templateId});

  @override
  ConsumerState<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends ConsumerState<TemplatePreviewScreen> {
  String _displayName = '';
  bool _showNameInput = false;
  bool _isSaved = false;
  bool _shareLoading = false;

  // In production, this would come from a Riverpod provider
  final _mockTemplate = {
    'nameHi': 'जय श्री राम',
    'quoteHi': '🙏 राम नाम सत्य है, बाकी सब झूठ है। जय श्री राम!',
    'gradient': [const Color(0xFFF7971E), const Color(0xFFFFD200)],
    'photoZoneEnabled': true,
    'nameZoneEnabled': true,
    'isPremium': false,
    'type': 'IMAGE',
  };

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Template Frame ─────────────────────────────
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _mockTemplate['gradient'] as List<Color>,
                ),
              ),
              child: Stack(
                children: [
                  // Photo Zone (circle placeholder)
                  if (_mockTemplate['photoZoneEnabled'] == true)
                    Positioned(
                      top: screenHeight * 0.22,
                      left: screenWidth * 0.5 - (screenWidth * 0.2),
                      child: GestureDetector(
                        onTap: () {/* Image picker in production */},
                        child: Container(
                          width: screenWidth * 0.4,
                          height: screenWidth * 0.4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_rounded, color: Colors.white60, size: 48),
                              Text('Tap to add\nyour photo', style: TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Quote Text
                  Positioned(
                    left: 24, right: 24,
                    top: screenHeight * 0.62,
                    child: Text(
                      _mockTemplate['quoteHi'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Name Zone
                  if (_mockTemplate['nameZoneEnabled'] == true)
                    Positioned(
                      left: 24, right: 24,
                      top: screenHeight * 0.77,
                      child: GestureDetector(
                        onTap: () => setState(() => _showNameInput = !_showNameInput),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            _displayName.isNotEmpty ? _displayName : 'अपना नाम लिखें ✏️',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Top Bar ─────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _isSaved = !_isSaved),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: _isSaved ? AppColors.warning : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Name Input Bottom Sheet ──────────────────────
          if (_showNameInput)
            Positioned(
              left: 16, right: 16,
              bottom: 160,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('अपना नाम लिखें', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _displayName = v),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Ramesh Gupta',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _showNameInput = false),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Action Bar ────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: Row(
                children: [
                  // Use Template
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {/* Download + open share sheet */},
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Status'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Download
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () {/* Download to gallery */},
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
