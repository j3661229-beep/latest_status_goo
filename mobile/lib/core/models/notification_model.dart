// lib/core/models/notification_model.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final bool isRead;
  final DateTime sentAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.imageUrl,
    this.isRead = false,
    required this.sentAt,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    String? imageUrl,
    bool? isRead,
    DateTime? sentAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'imageUrl': imageUrl,
      'isRead': isRead,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    String? img;
    if (json['imageUrl'] != null) {
      img = json['imageUrl'] as String;
    } else if (json['data'] != null && json['data'] is Map && json['data']['imageUrl'] != null) {
      img = json['data']['imageUrl'] as String;
    }

    DateTime parsedDate;
    if (json['sentAt'] != null) {
      parsedDate = DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      parsedDate = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return NotificationModel(
      id: json['id']?.toString() ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Status Go सूचना',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'NEW_CONTENT',
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
      imageUrl: img,
      isRead: json['isRead'] as bool? ?? false,
      sentAt: parsedDate,
    );
  }

  IconData get iconData {
    switch (type.toUpperCase()) {
      case 'DAILY_STATUS':
        return Icons.wb_sunny_rounded;
      case 'FESTIVAL_ALERT':
        return Icons.celebration_rounded;
      case 'PREMIUM_OFFER':
        return Icons.star_rounded;
      case 'TEMPLATE_APPROVED':
        return Icons.check_circle_rounded;
      case 'TEMPLATE_REJECTED':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get iconColor {
    switch (type.toUpperCase()) {
      case 'DAILY_STATUS':
        return const Color(0xFFE65100); // warm orange
      case 'FESTIVAL_ALERT':
        return const Color(0xFFD97706); // festive amber
      case 'PREMIUM_OFFER':
        return const Color(0xFF7C3AED); // premium purple
      case 'TEMPLATE_APPROVED':
        return const Color(0xFF16A34A); // green
      case 'TEMPLATE_REJECTED':
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFF1A56DB); // royal blue
    }
  }

  String get typeLabel {
    switch (type.toUpperCase()) {
      case 'DAILY_STATUS':
        return 'दैनिक स्टेटस';
      case 'FESTIVAL_ALERT':
        return 'त्योहार विशेष';
      case 'PREMIUM_OFFER':
        return 'प्रीमियम ऑफर';
      case 'TEMPLATE_APPROVED':
        return 'स्वीकृत स्टेटस';
      case 'TEMPLATE_REJECTED':
        return 'अपडेट आवश्यक';
      default:
        return 'सूचना';
    }
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(sentAt);

    if (diff.inMinutes < 1) {
      return 'अभी';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} मिनट पहले';
    } else if (diff.inDays == 0 && now.day == sentAt.day) {
      return DateFormat('hh:mm a').format(sentAt);
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != sentAt.day)) {
      return 'कल, ${DateFormat('hh:mm a').format(sentAt)}';
    } else {
      return DateFormat('dd MMM, hh:mm a').format(sentAt);
    }
  }
}
