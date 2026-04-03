import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<void> build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      _authRepository.signInWithEmailAndPassword(email, password)
    );
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      _authRepository.createUserWithEmailAndPassword(email, password)
    );
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signOut());
  }

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.deleteAccount());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(() {
  return AuthController();
});
