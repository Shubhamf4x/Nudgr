<div align="center">

# Nudgr

**All-in-one productivity & communication app — tasks, notes, focus, steps, world time and offline-first Bluetooth chat, in one lightweight package.**

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![APK](https://img.shields.io/badge/APK-arm64%20~22MB-brightgreen)

*made by woods*

</div>

---

## Overview

Nudgr is a local-first productivity app for Android. Everything you create — tasks, notes, focus sessions, step history — lives on your device by default and keeps working fully offline. When you sign in with Google, your data is also privately synchronized through your own Firebase account so it follows you to any device or reinstall. Bluetooth chat lets two nearby devices talk directly, with no server in between.

## Features

### Tasks
- Create tasks with title, description, priority (low / medium / high / urgent), due date & time, recurrence and subtasks with progress tracking.
- Categorize tasks (Work, Study, Personal, Fitness) — the category shows directly on the task card and syncs with the filter chips.
- Search across titles, descriptions and tags; filter by category and priority.
- Swipe-to-delete with confirmation, tap-to-complete, smart sorting (incomplete first, then priority, then due date).
- Local notifications remind you at the exact due time.

### Notes
- Distraction-free note editor with inline text formatting: **bold**, *italic*, underline, ~~strikethrough~~ and `code` styling rendered live.
- Pin important notes, search instantly, organize by category.
- Responsive two-column masonry grid that adapts to any screen width.

### Focus Timer
- Pomodoro-style focus sessions with configurable durations and breaks.
- Session history is persisted and synced, and completed sessions update your statistics.

### Step Tracking
- Uses the device's hardware step-counter sensor (no GPS, no location access).
- Daily goal with progress ring, goal-reached notification, weekly history and a calendar heatmap of past days.

### Calendar
- Month view of your tasks with event dots, holiday indicators and per-day detail dialogs.

### World Clock
- Your local time plus any number of city clocks using real IANA time zones (DST-correct year-round).
- Reorderable list, swipe to remove, 12/24-hour toggle and searchable city suggestions.

### Chat (Bluetooth Mesh)
- Device-to-device messaging over Bluetooth LE — messages travel directly between nearby phones.
- Works with no internet and stores conversations only on the participating devices. Chat logs never touch the cloud.

### Profile & Account
- Google sign-in or email/password registration with optional custom username.
- Profile photo with a built-in circular crop editor (camera or gallery), bio and statistics.
- Cloud sync status dashboard and manual "sync now".

### Updates
- Built-in **Check for updates**: the app compares its version against the latest GitHub Release and offers a one-tap download when a new build is published.

### Design
- Light and dark themes applied consistently across every screen.
- Custom floating pill navigation, smooth page transitions and a fast, splash-free startup.

## How It Works

### Local-first storage
All user data (tasks, notes, categories, focus sessions, steps) is persisted on-device via `SharedPreferences` as structured JSON through a dedicated `DatabaseService`. The UI is driven entirely by local state through `Provider` view-models (`TasksProvider`, `NotesProvider`, `FocusProvider`, `StepsProvider`, …), so every screen is instant and offline-capable.

### Cloud synchronization (Google accounts)
```
Flutter app ⇄ local storage ⇄ SyncService ⇄ Cloud Firestore ⇄ users/{uid}/…
```
- **Google sign-in** enables private cloud sync. Data is written under `users/{uid}/…` in Cloud Firestore and restored automatically on a new device or after reinstalling (notes, tasks, categories, focus history, steps and profile).
- **Email/password accounts are local-only**: their content never leaves the device (aside from authentication), and survives reinstalls through Android's built-in Auto Backup.
- An ownership guard wipes local data if a different account signs in, so two users' data can never mix.
- Offline edits are queued and flushed when connectivity returns; conflicts resolve last-write-wins per record.

### Security model
- Firebase Authentication is the only source of identity. Firestore Security Rules bind every document to the authenticated UID, validate field types and lengths, protect ownership fields from tampering and deny everything else by default.
- Private subcollections additionally require Google sign-in (`sign_in_provider == 'google.com'`), enforcing the local-only guarantee for email accounts server-side.
- Firebase App Check verifies that requests originate from the genuine app.
- Username→account mappings are strictly owned: no user can take over another user's username.
- Full details: [`SECURITY_HARDENING.md`](SECURITY_HARDENING.md).

### Notifications
Task due-time reminders and step-goal alerts are scheduled locally via `flutter_local_notifications` with exact-alarm support. The device's IANA time zone is resolved at startup so reminders fire at the correct local time, even across DST changes.

### Step counting
The Android host (`MainActivity`) exposes the hardware `TYPE_STEP_COUNTER` sensor over a method channel. A baseline strategy converts the sensor's cumulative boot counter into accurate daily counts that survive device reboots and app restarts, and only changed values are written or synced.

### Update system
`UpdateService` queries the GitHub Releases API for the repository configured in `AppConstants.githubRepo`, performs a semantic version comparison against the installed build and — when a newer tagged release with an APK asset exists — presents the release notes and a direct download link. Publishing an update is free: tag a release on GitHub, attach the APK, done.

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart 3), Material 3 |
| State management | Provider |
| Backend | Firebase Authentication, Cloud Firestore, Firebase App Check |
| Local storage | SharedPreferences |
| Notifications | flutter_local_notifications + timezone |
| Steps | Android `SensorManager` (`TYPE_STEP_COUNTER`) via MethodChannel |
| Chat | Bluetooth LE mesh (flutter_blue_plus) |
| Images | image_picker + image_cropper |
| Networking | dart:io HTTP (GitHub Releases check), url_launcher |
| Security | Firestore Security Rules, App Check (Play Integrity) |

## Project Structure

```
lib/
├── main.dart                  # App bootstrap, providers, error handlers
├── core/
│   ├── constants/             # App-wide constants
│   ├── services/              # auth, database, sync, steps, notifications, updates
│   ├── theme/                 # Theme system (light/dark)
│   └── utils/                 # Helpers, input validators
├── shared/
│   ├── models/                # Task, Note, Category, FocusSession, Step, User…
│   ├── providers/             # Theme, Sync status
│   └── widgets/               # Reusable cards, chips, empty states, nav bar
└── features/
    ├── auth/                  # Login, register, onboarding, splash-free startup
    ├── home/                  # Dashboard
    ├── tasks/                 # Tasks list + editor
    ├── notes/                 # Notes grid + formatted editor
    ├── focus/                 # Focus timer
    ├── steps/                 # Step counter & history
    ├── calendar/              # Task calendar
    ├── world_clock/           # World time screen
    ├── chat/                  # Bluetooth mesh chat
    ├── profile/               # Profile & settings entry points
    └── settings/              # Settings, appearance, legal screens
```

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+ (built with 3.47)
- Android SDK with a JDK 17 toolchain
- A Firebase project (the bundled `android/app/google-services.json` targets the `nudgr-d0911` demo project — replace it with your own for production)

### Run
```bash
flutter pub get
flutter run
```

### Build a release APK
```bash
# Universal APK (all CPU architectures)
flutter build apk --release

# Smaller per-device APKs
flutter build apk --release --split-per-abi
```
Output lands in `build/app/outputs/flutter-apk/`.

### Deploy the backend security rules
```bash
firebase deploy --only firestore:rules
```
(or paste `firestore.rules` into Firebase console → Firestore → Rules).

### Publishing an update to users
1. Bump `version:` in `pubspec.yaml`.
2. `flutter build apk --release --split-per-abi`.
3. On GitHub: **Releases → Draft a new release** → tag it (e.g. `v1.0.1`) → attach the APK → publish.
4. Users tapping *Check for updates* in the app are offered the new version.

### Firestore rules tests
A full authorization test matrix (Account A/B, ownership tampering, unauthenticated access) lives in [`firebase_tests/`](firebase_tests/) and runs against the Firebase Emulator Suite:
```bash
cd firebase_tests && npm install
firebase emulators:exec --only firestore "npm test"
```

## Data Safety Summary

| Data | Where it lives | Leaves the device? |
|---|---|---|
| Tasks, notes, categories | On device; cloud only for Google accounts | Only to your own private Firebase subtree |
| Focus history & steps | On device; cloud only for Google accounts | Only to your own private Firebase subtree |
| Profile photo | On device only | Never |
| Bluetooth chat | Participating devices only | Never (no server involved) |
| Credentials | Firebase Authentication | Managed by Google's auth infrastructure |

No ads. No analytics trackers. No data selling. See the in-app **Privacy Policy** and **Terms of Service** (Settings → Privacy) for the complete documents.

## License & Credits

All rights reserved © 2026 woods. Built with Flutter.
