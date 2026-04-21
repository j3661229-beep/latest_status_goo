// lib/features/search/presentation/screens/search_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search'), automaticallyImplyLeading: false),
    body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🔍', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
      Text('Search Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      SizedBox(height: 8),
      Text('Search in Hindi, Marathi & English', style: TextStyle(color: AppColors.textMuted)),
    ])),
  );
}
