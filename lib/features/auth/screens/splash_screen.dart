import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jaouda_boujdour_app/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authState = ref.read(authProvider);

    // Wait for a minimum duration to show the splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (authState.isAuthenticated) {
      // Route to appropriate dashboard based on user role
      if (authState.user?.role == 'admin') {
        context.go('/admin/dashboard');
      } else {
        context.go('/vendor/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 150,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: Text('JAOUDA')),
                );
              },
            ),
            const SizedBox(height: 24),
            // Loading Indicator
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Loading...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
