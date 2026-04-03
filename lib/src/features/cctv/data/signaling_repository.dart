import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingRepository {
  final FirebaseFirestore _firestore;
  final String? _deviceId;

  SignalingRepository(this._firestore, this._deviceId);

  Future<void> sendOffer(RTCSessionDescription offer) async {
    if (_deviceId == null) return;
    await _firestore.collection('devices').doc(_deviceId).collection('streaming').doc('session').set({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'status': 'offered',
    });
  }

  Future<void> sendAnswer(RTCSessionDescription answer) async {
    if (_deviceId == null) return;
    await _firestore.collection('devices').doc(_deviceId).collection('streaming').doc('session').update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'status': 'answered',
    });
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate, String side) async {
    if (_deviceId == null) return;
    await _firestore
        .collection('devices')
        .doc(_deviceId)
        .collection('streaming')
        .doc('session')
        .collection(side)
        .add(candidate.toMap());
  }

  Stream<DocumentSnapshot> watchSession() {
    return _firestore.collection('devices').doc(_deviceId).collection('streaming').doc('session').snapshots();
  }

  Stream<QuerySnapshot> watchIceCandidates(String side) {
    return _firestore
        .collection('devices')
        .doc(_deviceId)
        .collection('streaming')
        .doc('session')
        .collection(side)
        .snapshots();
  }

  Future<void> clearSession() async {
    if (_deviceId == null) return;
    final sessionRef = _firestore.collection('devices').doc(_deviceId).collection('streaming').doc('session');
    
    // Delete candidates subcollections
    final callerCandidates = await sessionRef.collection('caller_candidates').get();
    for (var doc in callerCandidates.docs) { await doc.reference.delete(); }
    
    final calleeCandidates = await sessionRef.collection('callee_candidates').get();
    for (var doc in calleeCandidates.docs) { await doc.reference.delete(); }

    await sessionRef.delete();
  }
}
