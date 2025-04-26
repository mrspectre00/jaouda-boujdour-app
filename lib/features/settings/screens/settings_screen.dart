import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/app_layout.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider).languageCode;

    return AppLayout(
      title: l10n.settings,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profile,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      user?.userMetadata?['name'] ?? 'Vendor Name',
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      user?.email ?? 'No email',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Regions Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.assignedRegions,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('Boujdour Region'),
                    subtitle: const Text('Primary region'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Language Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.language,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // English
                  RadioListTile<String>(
                    title: Text(l10n.english),
                    value: 'en',
                    groupValue: currentLocale,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(localeProvider.notifier).setLocale(value);
                      }
                    },
                  ),

                  // French
                  RadioListTile<String>(
                    title: Text(l10n.french),
                    value: 'fr',
                    groupValue: currentLocale,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(localeProvider.notifier).setLocale(value);
                      }
                    },
                  ),

                  // Arabic
                  RadioListTile<String>(
                    title: Text(l10n.arabic),
                    value: 'ar',
                    groupValue: currentLocale,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(localeProvider.notifier).setLocale(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Logout Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.account,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.logout),
                    onTap: () async {
                      final authNotifier = ref.read(authProvider.notifier);
                      await authNotifier.signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
