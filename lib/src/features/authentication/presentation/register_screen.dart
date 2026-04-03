import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _submit() async {
    await ref.read(authControllerProvider.notifier).register(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (_, state) {
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${state.error}'), backgroundColor: Colors.red),
          );
        }
      },
    );

    final state = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CREATE ACCOUNT')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_alt_1, size: 80, color: Color(0xFF00E5FF)),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password (min 6 chars)', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: state.isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text("Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}
