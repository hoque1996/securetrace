import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/geofence.dart';

class GeofenceRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GeofenceRepository(this._firestore, this._auth);

  Stream<List<Geofence>> watchGeofences() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('devices')
        .doc(user.uid)
        .collection('geofences')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Geofence.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> addGeofence(Geofence geofence) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('devices')
        .doc(user.uid)
        .collection('geofences')
        .add(geofence.toFirestore());
  }

  Future<void> deleteGeofence(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('devices')
        .doc(user.uid)
        .collection('geofences')
        .doc(id)
        .delete();
  }
}

final geofenceRepositoryProvider = Provider<GeofenceRepository>((ref) {
  return GeofenceRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final geofencesStreamProvider = StreamProvider<List<Geofence>>((ref) {
  return ref.watch(geofenceRepositoryProvider).watchGeofences();
});
