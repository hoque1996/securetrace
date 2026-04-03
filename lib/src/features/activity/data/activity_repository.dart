import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/activity_event.dart';

class ActivityRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ActivityRepository(this._firestore, this._auth);

  Stream<List<ActivityEvent>> watchActivity() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // We combine events from 'alerts', 'backups', and potentially 'devices' roots
    // For MVP, we'll watch the 'alerts' collection as it holds the most critical timeline data
    return _firestore
        .collection('devices')
        .doc(user.uid)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityEvent.fromFirestore(doc))
            .toList());
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final activityStreamProvider = StreamProvider<List<ActivityEvent>>((ref) {
  return ref.watch(activityRepositoryProvider).watchActivity();
});
