// lib/models/presentation_history.dart
import 'package:flutter/material.dart';

class PresentationHistory {
  final String id;
  final String sessionId;
  final String requesterId;
  final String requesterName;
  final List<String> requestedAttributes;
  final String purpose;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? fulfilledAt;
  final DateTime? completedAt;
  final Map<String, dynamic> sharedAttributes;
  final String? issuedCredentialId;
  final String? errorMessage;

  PresentationHistory({
    required this.id,
    required this.sessionId,
    required this.requesterId,
    required this.requesterName,
    required this.requestedAttributes,
    required this.purpose,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.fulfilledAt,
    this.completedAt,
    required this.sharedAttributes,
    this.issuedCredentialId,
    this.errorMessage,
  });

  factory PresentationHistory.fromJson(Map<String, dynamic> json) {
    return PresentationHistory(
      id: json['id'] ?? '',
      sessionId: json['sessionId'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      requestedAttributes: List<String>.from(json['requestedAttributes'] ?? []),
      purpose: json['purpose'] ?? '',
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(json['expiresAt'] ?? DateTime.now().toIso8601String()),
      fulfilledAt: json['fulfilledAt'] != null ? DateTime.parse(json['fulfilledAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      sharedAttributes: Map<String, dynamic>.from(json['sharedAttributes'] ?? {}),
      issuedCredentialId: json['issuedCredentialId'],
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requestedAttributes': requestedAttributes,
      'purpose': purpose,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'fulfilledAt': fulfilledAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'sharedAttributes': sharedAttributes,
      'issuedCredentialId': issuedCredentialId,
      'errorMessage': errorMessage,
    };
  }

  // Helper getters for display
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour < 12 ? 'AM' : 'PM';
    return '$hour.$minute $period';
  }

  String get sharedDataSummary {
    if (sharedAttributes.isEmpty) return 'No data shared';
    
    final firstTwo = sharedAttributes.entries.take(2).map((e) => '${e.key}: ${e.value}').join(', ');
    if (sharedAttributes.length <= 2) return firstTwo;
    return '$firstTwo, ...';
  }

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'FULFILLED':
        return 'Completed';
      case 'PENDING':
        return 'Pending';
      case 'REJECTED':
        return 'Rejected';
      case 'EXPIRED':
        return 'Expired';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'FULFILLED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      case 'EXPIRED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}