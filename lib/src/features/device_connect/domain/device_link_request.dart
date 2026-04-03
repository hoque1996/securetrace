import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceLinkRequest {
  final String id;
  final String deviceAId; // Creator of the QR
  final String? deviceBId; // Scanned by
  final String status; // 'pending', 'awaiting_approval', 'approved', 'rejected'
  final DateTime expiresAt;
  final String token; // OTP code fallback

  const DeviceLinkRequest({
    required this.id,
    required this.deviceAId,
    this.deviceBId,
    required this.status,
    required this.expiresAt,
    required this.token,
  });

  factory DeviceLinkRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceLinkRequest(
      id: doc.id,
      deviceAId: data['deviceA_id'] ?? '',
      deviceBId: data['deviceB_id'],
      status: data['status'] ?? 'pending',
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      token: data['token'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceA_id': deviceAId,
      'deviceB_id': deviceBId,
      'status': status,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'token': token,
    };
  }
}
