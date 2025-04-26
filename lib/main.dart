import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaouda_boujdour_app/config/theme.dart';
import 'package:jaouda_boujdour_app/config/router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Define fallback values
  final supabaseUrl =
      dotenv.env['SUPABASE_URL'] ?? 'https://hvxgdyxqmkpmhejpumlc.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2eGdkeXhxbWtwbWhlanB1bWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ0Nzk2OTMsImV4cCI6MjA2MDA1NTY5M30.JfS42uMEMgqNiKKfF17OKjMa6QRq6LUaJkESdAdLmdA';

  // Debug values during initialization
  debugPrint('SUPABASE_URL: $supabaseUrl');
  debugPrint('SUPABASE_ANON_KEY: ${supabaseAnonKey.substring(0, 10)}...');

  try {
    // Initialize Supabase with null-safe values
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
    // Continue with app initialization even if Supabase fails
  }

  // TODO: Add Firebase configuration before enabling this
  // await firestoreService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Jaouda Boujdour',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
