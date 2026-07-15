import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class AppSettings {
  final bool onboardingDone;
  final bool autoStartChecked;
  final int dailyReviewHour;
  final int dailyReviewMinute;
  final bool isLoading;

  const AppSettings({
    this.onboardingDone = false,
    this.autoStartChecked = false,
    this.dailyReviewHour = 22,
    this.dailyReviewMinute = 0,
    this.isLoading = true,
  });

  AppSettings copyWith({
    bool? onboardingDone,
    bool? autoStartChecked,
    int? dailyReviewHour,
    int? dailyReviewMinute,
    bool? isLoading,
  }) {
    return AppSettings(
      onboardingDone: onboardingDone ?? this.onboardingDone,
      autoStartChecked: autoStartChecked ?? this.autoStartChecked,
      dailyReviewHour: dailyReviewHour ?? this.dailyReviewHour,
      dailyReviewMinute: dailyReviewMinute ?? this.dailyReviewMinute,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _init();
  }

  Future<void> _init() async {
    try { await load(); } catch (_) {}
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      onboardingDone:
          prefs.getBool(AppConstants.keyOnboardingDone) ?? false,
      autoStartChecked:
          prefs.getBool(AppConstants.keyAutoStartChecked) ?? false,
      dailyReviewHour:
          prefs.getInt(AppConstants.keyDailyReviewHour) ?? 22,
      dailyReviewMinute:
          prefs.getInt(AppConstants.keyDailyReviewMinute) ?? 0,
      isLoading: false,
    );
  }

  Future<void> setOnboardingDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingDone, done);
    state = state.copyWith(onboardingDone: done);
  }

  Future<void> setAutoStartChecked(bool checked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoStartChecked, checked);
    state = state.copyWith(autoStartChecked: checked);
  }

  Future<void> setDailyReviewTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyDailyReviewHour, hour);
    await prefs.setInt(AppConstants.keyDailyReviewMinute, minute);
    state = state.copyWith(dailyReviewHour: hour, dailyReviewMinute: minute);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
        (ref) => SettingsNotifier());
