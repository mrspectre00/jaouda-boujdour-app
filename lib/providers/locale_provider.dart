import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider to store the current locale
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadSavedLocale();
  }

  // Load the saved locale from shared preferences
  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? languageCode = prefs.getString('languageCode');

      if (languageCode != null) {
        state = Locale(languageCode);
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    }
  }

  // Change the app locale
  Future<void> setLocale(String languageCode) async {
    try {
      // Save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', languageCode);

      // Update the state
      state = Locale(languageCode);
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }
}
