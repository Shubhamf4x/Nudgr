import 'package:firebase_core/firebase_core.dart';

/// Firebase settings that cannot live in `google-services.json` /
/// `GoogleService-Info.plist` — the browser has no config file mechanism, so
/// web values are supplied at build time.
///
/// Values are public client identifiers, not secrets; they are still kept out
/// of source control so a deployment can point at its own Firebase project:
///
/// ```
/// flutter build web \
///   --dart-define=FIREBASE_WEB_API_KEY=... \
///   --dart-define=FIREBASE_WEB_APP_ID=... \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=...apps.googleusercontent.com
/// ```
///
/// The project-level values default to the `nudgr-d0911` project that the
/// Android build already targets, so only the two per-app identifiers must be
/// provided. Native builds ignore all of this and keep reading their bundled
/// config files, exactly as before.
class FirebaseConfiguration {
  FirebaseConfiguration._();

  static const String webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );

  static const String webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');

  static const String webAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: 'nudgr-d0911.firebaseapp.com',
  );

  static const String webProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
    defaultValue: 'nudgr-d0911',
  );

  static const String webStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
    defaultValue: 'nudgr-d0911.firebasestorage.app',
  );

  static const String webMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    defaultValue: '363358004031',
  );

  static const String webRecaptchaSiteKey = String.fromEnvironment(
    'FIREBASE_WEB_RECAPTCHA_SITE_KEY',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get hasWebOptions => webApiKey.isNotEmpty && webAppId.isNotEmpty;

  static FirebaseOptions? get webOptions {
    if (!hasWebOptions) return null;
    return const FirebaseOptions(
      apiKey: webApiKey,
      appId: webAppId,
      messagingSenderId: webMessagingSenderId,
      projectId: webProjectId,
      authDomain: webAuthDomain,
      storageBucket: webStorageBucket,
    );
  }
}
