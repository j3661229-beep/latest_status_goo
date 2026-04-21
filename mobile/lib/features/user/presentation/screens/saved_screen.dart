// lib/features/user/presentation/screens/saved_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bookmarked Status')),
    body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🔖', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
      Text('Saved Templates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      SizedBox(height: 8),
      Text('Your bookmarked status templates appear here', style: TextStyle(color: AppColors.textMuted)),
    ])),
  );
}
