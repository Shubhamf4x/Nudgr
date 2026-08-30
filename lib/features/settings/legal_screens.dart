import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/color_constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Privacy Policy',
      lastUpdated: 'August 30, 2026',
      sections: _privacySections,
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScreen(
      title: 'Terms of Service',
      lastUpdated: 'August 30, 2026',
      sections: _termsSections,
    );
  }
}

const List<(String, List<String>)> _privacySections = [
  ('Overview', [
    'Nudgr ("the app", "we", "us") is a productivity application that provides '
        'task management, notes, a focus timer, step tracking, a world clock and '
        'a local Bluetooth chat feature. This policy explains what information '
        'the app handles, how it is stored, and the choices you have.',
    'The app is designed local-first: your content is stored on your device by '
        'default. Data is only sent to our cloud backend when you sign in with '
        'a Google account.',
  ]),
  ('Information We Collect', [
    'Account information. When you create an account or sign in, we process '
        'your email address, display name, username and (for Google sign-in) '
        'your Google profile name and profile photo URL. Authentication is '
        'handled by Firebase Authentication.',
    'User content. Notes (title, content, tags, pin/archive state), tasks '
        '(title, description, priority, due dates, subtasks, categories), '
        'focus session history and daily step counts are stored on your device.',
    'Profile information. A profile photo, bio and app statistics (task and '
        'note counts, focus minutes) are stored locally; for Google accounts a '
        'profile document is also kept in the cloud.',
    'Step data. If your device has a step-counter sensor and you grant the '
        'activity recognition permission, the app reads cumulative step counts '
        'from the hardware sensor to compute your daily steps. The app never '
        'uses this permission to determine your location.',
    'Log and diagnostics data. Like most apps, the Firebase infrastructure may '
        'generate technical logs necessary to operate and secure the service '
        '(for example, authentication events and App Check verification).',
  ]),
  ('What We Do NOT Collect', [
    'We do not show ads and we do not sell your data.',
    'We do not include third-party advertising or analytics trackers.',
    'We do not collect your contacts, precise location, or browsing history.',
    'Chat conversations are not collected: the Bluetooth chat feature exchanges '
        'messages directly between nearby devices over Bluetooth. Messages are '
        'stored only on the participating devices and never touch our servers.',
    'Your profile photo, when chosen from your gallery or camera, is cropped '
        'and stored on your device only. It is never uploaded.',
  ]),
  ('How Your Data Is Stored', [
    'Local storage. All app data lives in your device\'s private app storage. '
        'This storage is accessible only to the app.',
    'Cloud sync (Google accounts only). When you sign in with Google, your '
        'notes, tasks, categories, focus history, step history and profile are '
        'synchronized through Cloud Firestore (Google Firebase) so your content '
        'can be restored on a new device or after reinstalling. Cloud sync is '
        'tied to your Firebase user ID and is protected by security rules that '
        'prevent anyone else from reading or writing your data.',
    'Email/password accounts. Accounts created with an email address and '
        'password are local-only: your content never leaves your device through '
        'our backend (aside from the authentication itself and your username '
        'mapping, described below).',
    'Device backup. With your device\'s built-in Android backup enabled, your '
        'local app data may be backed up by your device manufacturer or Google '
        'so it can be restored when you reinstall the app or move to a new '
        'device. That backup is governed by your Google/device backup settings.',
  ]),
  ('Username Lookup', [
    'The app lets you log in with a username instead of an email address. To '
        'support this, a mapping between your username and your account email '
        'is stored in our database and must be readable before you sign in. '
        'Only you can create, change or delete the mapping for your own '
        'account.',
  ]),
  ('Permissions the App Uses', [
    'Activity recognition: to read your device\'s step counter (optional).',
    'Notifications (including exact alarms): to remind you of task due times '
        'and step goals.',
    'Camera and photo library: only when you choose to set a profile photo.',
    'Bluetooth and Nearby devices: only for the local chat feature, to discover '
        'and exchange messages with nearby devices that also run the app.',
    'You can revoke any permission at any time in your device settings; '
        'features that depend on it will stop working.',
  ]),
  ('Data Sharing', [
    'We share data only with the infrastructure providers needed to operate '
        'the app: Google Firebase (authentication and, for Google accounts, '
        'cloud data storage). These providers process data on our behalf under '
        'their own privacy and security terms.',
    'We do not otherwise share, sell or rent your personal information.',
  ]),
  ('Data Retention and Deletion', [
    'Local data remains on your device until you uninstall the app or clear '
        'its data.',
    'Signing out removes your session from the device.',
    'Deleting your account removes your local data. To also request deletion '
        'of cloud-synchronized data associated with your account, contact the '
        'developer through the channel where you obtained the app.',
  ]),
  ('Security', [
    'Access to your cloud data requires your Firebase authentication. Security '
        'rules on our backend enforce that every request belongs to the '
        'authenticated account, block tampering with ownership fields, and '
        'validate the structure of stored data. App Check is used to verify '
        'that requests come from the genuine app.',
    'No system is perfectly secure; please use a strong, unique password and '
        'keep your device locked.',
  ]),
  ('Children\'s Privacy', [
    'The app is not directed at children under 13. We do not knowingly collect '
        'personal information from children under 13.',
  ]),
  ('Changes to This Policy', [
    'We may update this policy as the app evolves. Material changes will be '
        'reflected in the app with an updated "last updated" date.',
  ]),
];

const List<(String, List<String>)> _termsSections = [
  ('Acceptance of Terms', [
    'By installing or using Nudgr ("the app") you agree to these Terms of '
        'Service. If you do not agree, do not use the app.',
  ]),
  ('The Service', [
    'Nudgr provides productivity tools including task management, notes, a '
        'focus timer, step tracking, a world clock and a local Bluetooth chat '
        'feature, together with optional account creation and (for Google '
        'accounts) cloud synchronization.',
    'Features may be added, changed or removed over time. We aim to keep the '
        'app useful but do not guarantee that any particular feature will '
        'remain available indefinitely.',
  ]),
  ('Accounts', [
    'You may use the app with a Google account or with an email/password '
        'account. You are responsible for keeping your credentials confidential '
        'and for all activity that occurs under your account.',
    'Accounts created with email/password keep your content on your device '
        'only. Google accounts additionally synchronize content to our cloud '
        'backend so it can be restored on other devices or after reinstalling.',
    'You must provide accurate registration information and be at least 13 '
        'years old (or the minimum digital-consent age in your country).',
  ]),
  ('Your Content', [
    'You keep ownership of the content you create with the app (notes, tasks, '
        'profile information and so on).',
    'You grant us only the limited technical permission needed to store and '
        'synchronize that content so the app can function (for example, '
        'storing your notes in your own cloud account when cloud sync is on).',
    'You are solely responsible for the content you create and share.',
  ]),
  ('Bluetooth Chat', [
    'The chat feature communicates directly with nearby devices over Bluetooth '
        'and stores messages locally. Messages are not routed through our '
        'servers and we do not moderate them.',
    'Do not use the chat feature to harass, threaten, or send unlawful '
        'content, and be mindful of what you share with nearby devices.',
  ]),
  ('Acceptable Use', [
    'You agree not to: use the app for any unlawful purpose; attempt to access '
        'another user\'s data or account; interfere with, overload or '
        'reverse-engineer our backend services; circumvent security rules or '
        'rate limits; or misrepresent your identity to other users.',
    'We may suspend or terminate access for violations of these terms.',
  ]),
  ('Health and Step Data', [
    'Step counts come from your device\'s sensor and are approximate. They are '
        'provided for general information only and are not medical advice. '
        'Consult a professional before making health decisions.',
  ]),
  ('Availability and Warranty', [
    'The app is provided "as is" and "as available" without warranties of any '
        'kind, express or implied, including fitness for a particular purpose. '
        'We do not warrant that the app will be uninterrupted or error-free.',
    'Cloud features depend on Firebase services and your internet connection; '
        'outages on those systems may temporarily affect sync and sign-in.',
  ]),
  ('Limitation of Liability', [
    'To the maximum extent permitted by law, the developer is not liable for '
        'indirect, incidental or consequential damages, or for loss of data '
        'arising from your use of the app. Keep your own backups of important '
        'content.',
  ]),
  ('Termination', [
    'You may stop using the app and delete your account at any time. Upon '
        'deletion, local data is removed; cloud data is handled as described '
        'in the Privacy Policy.',
  ]),
  ('Changes to These Terms', [
    'We may revise these terms from time to time. Continued use of the app '
        'after changes take effect constitutes acceptance of the revised '
        'terms.',
  ]),
];

class _LegalScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<(String, List<String>)> sections;

  const _LegalScreen({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = Theme.of(context).cardTheme.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: AppTextStyles.googleSans(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last updated: $lastUpdated',
              style: AppTextStyles.googleSans(
                fontSize: 12,
                color: subtextColor,
              ),
            ),
            const SizedBox(height: 20),
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.$1,
                      style: AppTextStyles.googleSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < section.$2.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            Text(
                              section.$2[i],
                              style: AppTextStyles.googleSans(
                                fontSize: 13.5,
                                height: 1.5,
                                color: textColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
