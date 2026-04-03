import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/device_connect_repository.dart';
import '../domain/device_link_request.dart';
import 'package:firebase_auth/firebase_auth.dart';

// TODO: Replace with actual device ID logic from native code/device_info_plus later.
final currentDeviceIdProvider = Provider<String>((ref) {
  return FirebaseAuth.instance.currentUser?.uid ?? 'unknown_device';
});

class DeviceConnectController extends AsyncNotifier<void> {
  late final DeviceConnectRepository _repo;

  @override
  FutureOr<void> build() {
    _repo = ref.watch(deviceConnectRepoProvider);
  }

  Future<DeviceLinkRequest?> generateQR() async {
    state = const AsyncLoading();
    try {
      final deviceId = ref.read(currentDeviceIdProvider);
      final request = await _repo.createLinkRequest(deviceId);
      state = const AsyncData(null);
      return request;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> scanQR(String qrData) async {
    state = const AsyncLoading();
    try {
      final deviceId = ref.read(currentDeviceIdProvider);
      await _repo.scanAndClaimRequest(qrData, deviceId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow; 
    }
  }

  Future<void> approve(String requestId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.approveRequest(requestId));
  }

  Future<void> reject(String requestId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.rejectRequest(requestId));
  }
}

final deviceConnectControllerProvider = AsyncNotifierProvider<DeviceConnectController, void>(() {
  return DeviceConnectController();
});

final linkRequestStreamProvider = StreamProvider.family<DeviceLinkRequest?, String>((ref, requestId) {
  return ref.watch(deviceConnectRepoProvider).watchLinkRequest(requestId);
});
