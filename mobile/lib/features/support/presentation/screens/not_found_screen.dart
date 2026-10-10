// lib/features/support/presentation/screens/not_found_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_ui.dart';

/// Shown by the router's errorBuilder for unknown routes / failed navigation.
class NotFoundScreen extends StatelessWidget {
  final String? path;
  const NotFoundScreen({super.key, this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.explore_off_rounded,
          title: 'यह पेज नहीं मिला',
          message: 'शायद लिंक पुराना है या पेज हटा दिया गया है।${path == null ? '' : '\n$path'}',
          actionLabel: 'होम पर जाएं',
          onAction: () => context.go('/home'),
        ),
      ),
    );
  }
}
