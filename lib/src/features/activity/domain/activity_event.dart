import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  location,
  alert,
  backup,
  security,
  connection
}

class ActivityEvent {
  final String id;
  final ActivityType type;
  final DateTime timestamp;
  final String title;
  final String message;
  final Map<String, dynamic>? metadata;

  ActivityEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.title,
    required this.message,
    this.metadata,
  });

  factory ActivityEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeStr = data['type'] as String? ?? 'security';
    
    ActivityType type;
    if (typeStr.contains('alert')) {
      type = ActivityType.alert;
    } else if (typeStr.contains('backup')) {
      type = ActivityType.backup;
    } else if (typeStr.contains('location')) {
      type = ActivityType.location;
    } else if (typeStr.contains('connection') || typeStr.contains('pair')) {
      type = ActivityType.connection;
    } else {
      type = ActivityType.security;
    }

    return ActivityEvent(
      id: doc.id,
      type: type,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: _getTitleForType(typeStr, data),
      message: data['message'] as String? ?? '',
      metadata: data,
    );
  }

  static String _getTitleForType(String typeStr, Map<String, dynamic> data) {
    switch (typeStr) {
      case 'intruder_alert': return 'Intruder Detected';
      case 'sim_change_alert': return 'SIM Card Changed';
      case 'sim_removed_alert': return 'SIM Removal Warning';
      case 'contacts_backup': return 'Contacts Synced';
      case 'media_backup': return 'Vault Update';
      case 'pair_request': return 'New Link Request';
      case 'paired': return 'Device Linked';
      case 'ai_pattern_alert': return 'Sudden Movement Detected';
      default: return 'Security Event';
    }
  }
}
