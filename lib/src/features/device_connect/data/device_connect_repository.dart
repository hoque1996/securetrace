import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/device_link_request.dart';
import 'package:uuid/uuid.dart';

class DeviceConnectRepository {
  final FirebaseFirestore _db;

  DeviceConnectRepository(this._db);

  /// Device A generates a secure connection request valid for 30s-5m.
  Future<DeviceLinkRequest> createLinkRequest(String currentDeviceId) async {
    final token = const Uuid().v4().substring(0, 6).toUpperCase(); 
    final docRef = _db.collection('device_links').doc();
    
    final request = DeviceLinkRequest(
      id: docRef.id,
      deviceAId: currentDeviceId,
      status: 'pending',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)), 
      token: token,
    );

    await docRef.set(request.toMap());
    return request;
  }

  /// Device A actively listens to the request status pending B's scan.
  Stream<DeviceLinkRequest?> watchLinkRequest(String requestId) {
    return _db.collection('device_links').doc(requestId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DeviceLinkRequest.fromFirestore(doc);
    });
  }

  /// Device B scans the QR and claims the token, pausing for Device A's explicit manual approval.
  Future<void> scanAndClaimRequest(String qrDataId, String currentDeviceId) async {
    final docRef = _db.collection('device_links').doc(qrDataId);
    final doc = await docRef.get();

    if (!doc.exists) throw Exception('Invalid QR Code. Token not found.');
    
    final request = DeviceLinkRequest.fromFirestore(doc);
    if (request.expiresAt.isBefore(DateTime.now())) {
      throw Exception('QR Code has expired for security purposes.');
    }
    if (request.status != 'pending') {
      throw Exception('This QR Code has already been consumed.');
    }

    // Device B successfully intercepts, changing state to awaiting_approval
    await docRef.update({
      'deviceB_id': currentDeviceId,
      'status': 'awaiting_approval',
    });
  }

  /// Device A clicks "Approve Tracking"
  Future<void> approveRequest(String requestId) async {
    await _db.collection('device_links').doc(requestId).update({
      'status': 'approved',
    });
  }
  
  /// Device A clicks "Reject"
  Future<void> rejectRequest(String requestId) async {
    await _db.collection('device_links').doc(requestId).update({
      'status': 'rejected',
    });
  }
}

final deviceConnectRepoProvider = Provider((ref) {
  return DeviceConnectRepository(FirebaseFirestore.instance);
});
