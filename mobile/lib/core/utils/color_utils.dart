// lib/core/utils/color_utils.dart
import 'package:flutter/material.dart';

class ColorUtils {
  ColorUtils._();

  /// Parses a list of colors from a string.
  /// Handles both comma-separated hex codes and CSS linear-gradient strings.
  static List<Color> parseGradientString(String? gradientStr) {
    if (gradientStr == null || gradientStr.isEmpty) {
      return [const Color(0xFF7C5CFC), const Color(0xFFFF6B9D)]; // Fallback brand colors
    }

    // Regex to match hex codes (e.g., #FF9B82, #F7971E)
    final hexRegex = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})');
    final matches = hexRegex.allMatches(gradientStr);

    if (matches.isEmpty) {
      // Try parsing as comma-separated integers if hex isn't found (Legacy support)
      try {
        return gradientStr
            .split(',')
            .map((c) => Color(int.parse(c.trim().replaceAll('#', '0xFF'))))
            .toList();
      } catch (_) {
        return [const Color(0xFF7C5CFC), const Color(0xFFFF6B9D)];
      }
    }

    return matches.map((m) {
      String hex = m.group(1)!;
      if (hex.length == 3) {
        // Handle short hex: #RGB -> #RRGGBB
        hex = hex.split('').map((c) => '$c$c').join();
      }
      return Color(int.parse('0xFF$hex'));
    }).toList();
  }
}
