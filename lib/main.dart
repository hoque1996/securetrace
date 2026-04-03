import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'src/core/theme/app_theme.dart';
import 'src/routing/app_router.dart';
import 'src/features/tracking/application/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeBackgroundService();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enforce offline queueing capabilities natively
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ProviderScope(child: SecureTraceApp()));
}

class SecureTraceApp extends ConsumerWidget {
  const SecureTraceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SecureTrace AI',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
