class AppConstants {
  AppConstants._();
  static const String appName = 'Nudgr';
  static const String fontFamily = 'Inter';
  static const int defaultFocusDuration = 25;
  static const int defaultShortBreak = 5;
  static const int defaultLongBreak = 15;
  static const int defaultSessionsBeforeLongBreak = 4;

  /// GitHub repository ("username/repo") used for the free check-for-updates
  /// system. Publish a GitHub Release with an APK asset and users will be
  /// notified of updates. Replace the placeholder with your real repository.
  static const String githubRepo = 'YOUR_GITHUB_USERNAME/nudgr';
}
