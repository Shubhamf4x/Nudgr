# Nudgr — Backend Security Hardening Report

Date: 2026-08-29
Scope: Firebase Authentication, Cloud Firestore, (optional) Firebase Storage, App Check, and all Flutter ↔ Firebase synchronization paths.

---

## 1. Implemented backend changes

### firestore.rules (deploy to production)

Rules were rewritten against the **actual** database structure:

| Path | Purpose | Access |
|---|---|---|
| `users/{uid}` | Profile document (UserModel) | Owner only, `id` must equal path `uid`, `createdAt` immutable, delete denied from client |
| `users/{uid}/tasks/{taskId}` | TaskModel | Owner only, ownership field locked to caller, field validation |
| `users/{uid}/notes/{noteId}` | NoteModel | Owner only, title ≤ 200, content ≤ 100 000 chars |
| `users/{uid}/categories/{categoryId}` | CategoryModel | Owner only, name 1–100, colorIndex 0–100 |
| `users/{uid}/focus_sessions/{id}` | Focus history | Owner only, durations capped at 1440 min |
| `users/{uid}/steps/{date}` | Daily step history | Owner only, doc ID must be `YYYY-MM-DD`, `date` field must match doc ID, stepCount 0–1 000 000 |
| `users/{uid}/conversations/{id}` | Chat metadata | Owner only |
| `usernames/{username}` | Username → email/uid mapping | **Public read** (required pre-auth by the login flow), writes strictly bound to `request.auth.uid`, doc-ID charset enforced, update can never re-point the mapping at another UID |
| everything else | — | **Deny all** |

Enforced security properties:

1. **Authenticated user + own UID = allowed.** Every rule is anchored on `request.auth.uid` compared against the *path* UID (`isOwner(uid)`), never on client-supplied fields alone.
2. **Authenticated user + different UID = rejected.** Writing into `users/{uidB}/...` is denied even if the payload stamps `userId: uidA`.
3. **Unauthenticated access to private data = rejected.** Only `usernames/{username}` lookups are public (by design — see §7).
4. **Ownership-field protection.** `userId` on subcollection writes must equal `request.auth.uid`; `id` must equal the document ID; `createdAt` is immutable on update (reassignment attempts fail the rules).
5. **Input validation server-side.** Type checks, length caps, enum checks (`priority in ['low','medium','high']`), integer ranges, and email/username format checks — see the rules file for the per-collection details.
6. **Client-side trust.** The Flutter app is treated as untrusted: it can only ever reach its own subtree, and only with well-formed documents.

> Note: the client writes full model JSON via `set(merge: true)`, so rules validate the *resulting merged document*. The rules were written to match exactly this write pattern so the existing sync architecture keeps working unchanged.

### storage.rules (new)

The app currently does **not** use Firebase Storage (profile photos are stored on-device), so all client Storage access is denied by default. A ready-to-enable owner-scoped template (`users/{uid}/profile/*`, images only, < 5 MiB) is included for future use.

### App Check (Android)

- Added `firebase_app_check` and activated it in `lib/main.dart`:
  - **Debug builds** → `AndroidProvider.debug` (register the debug token in Firebase console → App Check → Apps → Manage debug tokens).
  - **Release builds** → `AndroidProvider.playIntegrity` (the supported provider for this Android configuration).
- Activation is wrapped in `try/catch` and never blocks startup. With App Check left in **monitoring mode** (default), the app works immediately; enforcement can be enabled in the console after rollout — App Check is only *enforced* on Firestore/Auth once you switch enforcement on, so nothing breaks for sideloaded APKs during testing.

### Client-side validation (defense in depth)

- New `lib/core/utils/validators.dart`: length clamps matching the server limits, username sanitizer (lowercase, `[a-z0-9._-]`, ≤ 32 chars), email/password validators.
- `AuthService.register/login/Google sign-in` now route **all** usernames through the sanitizer before any uniqueness check or Firestore write — the `usernames` doc ID is always safe.
- Note editor clamps title/content to the server-enforced limits so cloud sync never rejects a write.
- Register screen validates username charset/length up front.

### Credential hygiene

- `android/key.properties` (keystore passwords) and `android/app/debug-keystore.jks` exist locally and are now listed in `.gitignore` (with service-account JSON patterns) so they can never be committed. **They were not deleted** — the release build needs them.
- `android/app/google-services.json` contains only *public client configuration* (API key + app ID) — this is safe and required to ship in the APK; it is not a privileged credential. It is still protected by the hardened Firestore/Storage rules and (once enabled) App Check enforcement.
- No service-account keys, private keys, or server secrets were found in the repository.

---

## 2. Deployment steps (required to activate the backend hardening)

The rules files are in the repo root; deploy them to the Firebase project (`nudgr-d0911`):

```bash
# one-time, if not configured yet
firebase init firestore   # select existing project, keep existing firestore.rules
firebase init storage     # optional, selects storage.rules

# deploy
firebase deploy --only firestore:rules
firebase deploy --only storage
```

Or paste `firestore.rules` / `storage.rules` into the Firebase console → Firestore / Storage → Rules → Publish. Deploying rules requires no app update and applies immediately to existing and new clients.

### Enabling App Check (recommended sequence)

1. Firebase console → App Check → register the Android app (`com.nudgr.nudgr`) with **Play Integrity**.
2. Install this release APK, open the app once — it starts sending tokens.
3. Watch the *Metrics* tab; when 100 % of requests carry a verified token, enable **Enforce** for Cloud Firestore (and Authentication if desired).

---

## 3. Security rule testing (requirements 17 & 18)

`firebase_tests/firestore.rules.test.js` contains a full A/B test matrix:

- Account A (UID_A) → A's data: **allowed** (create / read / update / delete on notes, tasks, categories, focus sessions, steps, profile)
- Account A → B's data: **rejected** (read / update / delete / create in B's subtree)
- Account B → A's data: **rejected**
- Unauthenticated → private data: **rejected**
- Ownership-field tampering (`userId` reassignment, `id` change, `createdAt` rewrite, username-mapping theft): **rejected**
- Payload validation (oversized title, negative steps, bad priority enum, invalid username doc ID): **rejected**

Run them against the emulator (never production):

```bash
cd firebase_tests
npm install
firebase emulators:exec --only firestore "npm test"
```

---

## 4. Architecture review — remaining items & recommendations

### Authentication (req 6) — OK
- Email/password + Google Sign-In via Firebase Auth; sessions are managed by the Firebase SDK (token refresh, persistence); logout calls `signOut()` on both Google and Firebase; account switching flows through the same auth-state path. Private data is only reachable with a valid Firebase ID token.

### Username system (req 7) — reviewed, see notes
- Public read of `usernames` is **required** by the pre-auth username→email resolution. This exposes the email bound to a username by design. Hardening applied: strictly owned writes, charset-validated doc IDs, sanitized lookups, owner-only mapping updates/deletes.
- **Recommendation:** move uniqueness + mapping creation into a Cloud Function (transactional check) and store a hash of the email instead of the plaintext email to remove the exposure entirely.

### Rate limiting & abuse protection (req 12)
- Firebase Auth has built-in rate limiting / reCAPTCHA for auth endpoints (visible as `too-many-requests`, already handled in the client).
- Firestore rules cannot rate-limit; the correct lever is **App Check enforcement** (blocks non-app traffic) plus the per-document validation added here. Username lookups are cheap single-doc reads; once App Check is enforced, scripted abuse is largely mitigated.

### Server-side privileged operations (req 11)
- No privileged operations are performed from the client today (the client's account-delete attempts on the `users` doc are denied by rules and swallowed silently — intentional).
- **Recommendation:** implement account deletion, username release, and any future admin work in **Cloud Functions** with the Admin SDK; keep all privileged credentials out of the APK.

### Offline data + reconnection (req 16) — OK
- Offline persistence and the app's own sync queue both funnel writes through the normal Firestore pipeline; rules are evaluated **server-side at write time**, so queued offline writes cannot bypass authorization after reconnection. Conflict resolution is last-write-wins scoped to the signed-in user's own subtree, so no cross-user overwrite is possible.

### Security monitoring (req 20)
- Firebase console → Firestore → Usage (rejections), App Check → Metrics (unverified traffic), Auth → Users/Activity.
- Cloud Logging retains rule-violation telemetry when App Check enforcement is on. Investigation is possible without exposing user document contents.

### Production configuration (req 19)
- Development vs production: consider a second Firebase project for testing; deploy rules per project.
- Auth providers: restrict sign-up by email domain if desired; set password policy in console.
- Allowed domains / OAuth clients: `google-services.json` currently has no OAuth clients configured — Google Sign-In depends on the default SHA-1 registration; register the release SHA-256 in the Firebase console if Google sign-in is used in release.
- Release application identifier: `com.nudgr.nudgr` (matches `google-services.json`).

---

## 5. App changes in this pass (non-backend)

1. **Notes grid layout fixed** (`lib/features/notes/notes_screen.dart`): the masonry `SizedBox` was wider than the viewport by the horizontal padding (40 px), clipping the cards' right border. Grid width is now viewport − padding, columns recomputed accordingly, plus bottom padding so the FAB never covers the last row.
2. **Focus statistics removed** from the Profile page menu.
3. Fixed pre-existing compile errors (`const` misuse of non-const `ColorConstants.primary` in `app_theme.dart`, `loading_widget.dart`, `chat_list_screen.dart`, `chat_screen.dart`) and replaced the stale `test/widget_test.dart` with working unit tests.
4. `flutter analyze`: 0 errors. `flutter test`: 9/9 passed.

## 6. APK

`build/app/outputs/flutter-apk/app-release.apk` (≈ 62 MB, signed with the project keystore, versionName 1.0.0).

---

## 7. Update (2026-08-30) — cloud sync policy

- Cloud sync is now a **Google-account feature**. `SyncService` is gated on the signed-in provider (detected from Firebase `providerData`); email/password accounts never touch Firestore.
- Enforced server-side as well: `firestore.rules` now requires `request.auth.token.firebase.sign_in_provider == 'google.com'` for all private subcollections. The `users/{uid}` profile doc and `usernames` mapping remain available to email accounts (login/username features need them). Re-deploy rules after this change: `firebase deploy --only firestore:rules`.
- Restore path for Google users on a new device/reinstall: notes, tasks, categories, focus sessions, **steps** (new) and the **profile document** (new) are pulled and merged on login. Cloud profile wins only when strictly newer than local.
- Local-data ownership guard: when a different account signs in on a device, local data is wiped first so one user's content can never leak into another user's cloud account.
- Email/password accounts survive reinstall via **Android Auto Backup** (free): `allowBackup` + `backup_rules.xml` / `data_extraction_rules.xml` include shared prefs, files and databases (Firestore cache excluded).
