# Cross-platform setup — Nudgr

Nudgr runs from one Flutter codebase on **Android**, **iOS** and the **web**.
Android is the reference platform and needs no extra setup. This document lists
the one-time external steps (all of them in the Firebase console / Xcode) plus
the exact build commands for the other two targets.

No secrets belong in this repository. Values such as `apiKey` / `appId` are
public identifiers and are still passed at build time via `--dart-define`, not
committed.

## Platform support matrix

| Feature | Android | iOS | Web |
|---|---|---|---|
| Tasks, notes, focus, calendar, world clock | ✅ | ✅ | ✅ |
| Local accounts (email/password) | ✅ | ✅ | ✅ (browser storage) |
| Google sign-in + cloud sync | ✅ | ✅ | ✅ (needs setup below) |
| Profile photo (pick + crop) | ✅ | ✅ | ✅ (stored as a data URL) |
| Step tracking | ✅ (hardware sensor) | ❌ no pedometer bridge yet | ❌ |
| Task reminders / notifications | ✅ | ✅ (local only, no APNs) | ❌ no scheduling API wired |
| Bluetooth mesh chat | ❌ transport not implemented | ❌ transport not implemented | ❌ |
| Check-for-updates (GitHub APK) | ✅ | ❌ | ❌ |

Screens that rely on a missing capability show an explanatory unavailable state
instead of failing silently.

## Android

Android is the reference platform and needs no extra build configuration beyond
the Android SDK. Before using Firebase from Android, replace the placeholder
`android/app/google-services.json` (see the README prerequisites) — it ships
targeting the `nudgr-d0911` demo project and must be regenerated from the
Firebase console for any real run: **Project settings → Your apps → Add app →
Android → package `com.nudgr.nudgr` → download `google-services.json`**.

Step tracking uses a native foreground service (`StepTrackingService`) with the
`ACTIVITY_RECOGNITION` runtime permission; the persistent notification uses the
bundled drawable `drawable/ic_stat_nudgr.xml` (verified by `tool\build_apks.ps1`).
Task reminders schedule exact alarms (`SCHEDULE_EXACT_ALARM`).

---

## Web

### 1. Register a web app in Firebase

1. Firebase console → project **nudgr-d0911** (or your own project) →
   **Project settings → General → Your apps → Add app → Web**.
2. Copy the **apiKey** and **appId** from the shown snippet (the whole
   `firebaseConfig` block is useful too).

### 2. Build (and run) with the values

The two defines below are required — without them the app boots into a clear
"no Firebase configuration" state instead of crashing:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_WEB_API_KEY=<web apiKey> \
  --dart-define=FIREBASE_WEB_APP_ID=<web appId>

flutter build web --release \
  --dart-define=FIREBASE_WEB_API_KEY=<web apiKey> \
  --dart-define=FIREBASE_WEB_APP_ID=<web appId>
```

Optional defines:

| Define | Purpose |
|---|---|
| `GOOGLE_WEB_CLIENT_ID` | Enables the Google sign-in button on web |
| `FIREBASE_WEB_RECAPTCHA_SITE_KEY` | Enables Firebase App Check (reCAPTCHA v3) |
| `FIREBASE_WEB_AUTH_DOMAIN` | Only for a different project |
| `FIREBASE_WEB_PROJECT_ID` | Only for a different project |
| `FIREBASE_WEB_STORAGE_BUCKET` | Only for a different project |
| `FIREBASE_WEB_MESSAGING_SENDER_ID` | Only for a different project |

The defaults for the last four already point at the bundled `nudgr-d0911`
project, so a build for that project only needs the two required defines.

### 3. Google sign-in on web

1. Firebase console → **Authentication → Sign-in method → Google** → enable.
2. Under the Google provider, copy the **Web client ID** (Web SDK configuration)
   and pass it as `GOOGLE_WEB_CLIENT_ID`. The app refuses to start the Google
   flow when it is missing, with a readable message.
3. Firebase console → **Authentication → Settings → Authorized domains** — add
   the domain the app is hosted on (e.g. `<project>.web.app`) and `localhost`
   for local testing. Google sign-in fails with `auth/unauthorized-domain`
   otherwise.

### 4. Firestore rules (same as Android)

The backend rules are shared with Android — deploy them once:

```bash
firebase deploy --only firestore:rules
```

### 5. App Check (optional, recommended)

1. Firebase console → **App Check → Apps → Add app → Web → reCAPTCHA v3**, get
   a site key (register `localhost` too for development).
2. Rebuild with `--dart-define=FIREBASE_WEB_RECAPTCHA_SITE_KEY=<site key>`.
3. Only turn on enforcement in the console once your deployed build uses it.

### Web behaviour notes

- **Auth persistence** uses Firebase's default browser persistence
  (IndexedDB/localStorage), so a signed-in session survives reloads.
- **Email/password accounts stay local to the browser** — the same guarantee as
  Android; nothing is uploaded.
- **No local notifications**: the browser Notification API plus a service worker
  is not wired yet, so reminders are not scheduled and the permission prompt is
  skipped.
- **No step tracking** and **no update check** (Android-only features).
- Profile photos picked in the browser are converted to `data:` URLs before
  being stored, because `blob:` URLs do not survive a page reload.

---

## iOS

iOS builds require **macOS + Xcode**; the project sources in `ios/` are already
prepared (display name "Nudgr", camera/photo usage descriptions, bundle ID
`com.nudgr.nudgr`), but the steps below can only be completed on a Mac.

### 1. Register the app in Firebase (once, any machine)

1. Firebase console → project **nudgr-d0911** → **Add app → iOS**.
2. Bundle ID: `com.nudgr.nudgr`.
3. Download `GoogleService-Info.plist`.

### 2. Wire the project (on macOS)

1. Copy `GoogleService-Info.plist` into `ios/Runner/` and add it to the Runner
   target in Xcode (drag into the project navigator, "Copy items if needed").
2. Google sign-in URL scheme: in Xcode open `ios/Runner/Info.plist` and add a
   URL type whose scheme is the **REVERSED_CLIENT_ID** value from
   `GoogleService-Info.plist` (e.g. `com.googleusercontent.apps.363358004031-…`).
3. CocoaPods: the plugin versions pinned in `pubspec.lock` do not ship Swift
   Package Manager manifests yet, so the Flutter tool generates a `Podfile` on
   the first build and uses CocoaPods. Install it once with
   `gem install cocoapods` (or `brew install cocoapods`).
4. Build and run:

   ```bash
   flutter pub get
   flutter build ios --release        # or: flutter run -d <device>
   ```

### 3. Firebase console — finish Google sign-in

- **Authentication → Sign-in method → Google** must be enabled (same provider as
  Android/web; nothing else to add for the iOS client).
- The `REVERSED_CLIENT_ID` URL scheme in step 2 is what returns the user from
  the Google sign-in browser sheet to the app.

### iOS behaviour notes

- **Notifications are local only** (`flutter_local_notifications`); the plugin
  asks for the system permission itself. No APNs/remote push is configured.
- **No step tracking**: `TYPE_STEP_COUNTER` is Android-only and no
  `CMPedometer` bridge is wired yet, so the Steps tab shows the unavailable
  state.
- **No update check** (Android APK flow).
- **No Bluetooth mesh chat** — disabled on disk like everywhere else until a
  transport exists.

---

## Verification status

| Check | Where | Result |
|---|---|---|
| `flutter analyze` | Windows | clean |
| `flutter test` (94 tests) | Windows | all pass |
| `flutter build web --release` | Windows | succeeds |
| `flutter build apk --debug` | Windows | succeeds |
| `flutter build ios` | **not run** — needs macOS + Xcode | ⏳ |
| Web runtime against a live Firebase project | **not run** — needs console values above | ⏳ |
| iOS run on device/simulator | **not run** — needs macOS + Xcode | ⏳ |

Anything marked ⏳ has code in place and is expected to work, but has not been
executed end-to-end; treat it as requiring one real run on the appropriate
machine before shipping.
