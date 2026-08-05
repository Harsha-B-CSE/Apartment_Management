# ApartmentApp — Upgraded SaaS AMS
## Complete Setup & Change Log

---

## What Was Changed (Per Your 10 Requirements)

### ✅ Req 1 — Android Only
- **Deleted:** `ios/` folder entirely
- **Fixed:** `notification_service.dart` — removed all `DarwinNotificationDetails`, `DarwinInitializationSettings`
- **Fixed:** `pubspec.yaml` — no iOS-specific packages
- **Action required:** Run `flutter clean` then `flutter pub get`

---

### ✅ Req 2 — Frontend Colors & Firebase
- **Colors:** Verified — `AppColors` class unchanged (correct)
- **Firebase:** Added `firebase_app_check` to `pubspec.yaml` + activated in `main.dart`
- **Fixed:** All Firestore queries now scoped by `buildingId` (was missing — data leakage between buildings)
- **Deploy rules:** `firebase deploy --only firestore:rules,firestore:indexes`

---

### ✅ Req 3 — Optimized for Low Resources / Slow Network
| Optimization | File |
|---|---|
| Hive local cache (5-30 min TTL) | `cache_service.dart` |
| Stale-while-revalidate on dashboard | `admin_dashboard_screen.dart` |
| Offline banner + graceful degradation | `app_widgets.dart` → `OfflineBanner` |
| Connectivity detection | `connectivity_service.dart` |
| Pagination (20 docs/page) | `firestore_service.dart` → `pageSize` |
| Retry wrapper (3 retries, backoff) | `firestore_service.dart` → `_withRetry` |
| Text scale clamped (0.85–1.2×) | `main.dart` → `MediaQuery` wrap |
| Shimmer loading (not spinner) | `app_widgets.dart` → `LoadingList` |
| Portrait lock (no layout jank) | `main.dart` → `SystemChrome` |

---

### ✅ Req 4 — Two Logins (Admin + Tenant)
- **BUGFIX:** Login was routing to `/admin/dashboard` — **route does not exist** = crash. Fixed to `/admin` and `/member`.
- Admin sees: Dashboard, Members, Flats, Buildings, Complaints, Visitors, Parking, Services, Service Requests, Notifications, Profile
- Member sees: Dashboard, My Complaints, My Visitors, My Parking, Service Requests, Notifications, Profile
- Role guard in router: admin cannot visit `/member/*` and vice versa

---

### ✅ Req 5 — SaaS White-labelling
**Per-client deployment steps:**
1. Edit `assets/config/saas_config.json` with client name, colors, admin email
2. Change `applicationId` in `android/app/build.gradle` to `com.CLIENTNAME.ams`
3. Replace `google-services.json` with client's Firebase project config
4. Build APK: `flutter build apk --release`

**Remote config (no APK rebuild):**  
Push updated JSON to Firestore `saas_config/main` doc — app picks it up on next launch.

---

### ✅ Req 6 — Fast, Responsive, Smooth Transitions
- Fade transition on auth screens (220ms)
- Slide+fade on all navigation transitions (280ms)
- `flutter_animate` package added for list item animations
- `OfflineBanner` uses `SizeTransition` (not abrupt show/hide)
- Dashboard data appears instantly from cache, refreshes silently

---

### ✅ Req 7 — Load Balancing / High Traffic
Firebase auto-scales horizontally — no server config needed. App-side:
- All list queries use `limit(20)` pagination — no full-collection reads
- Dashboard uses Firestore **aggregation queries** (count) — not full reads
- Compound indexes in `firestore.indexes.json` — deploy these to avoid slow queries under load
- App Check blocks bot/scraper traffic from hitting your quota

---

### ✅ Req 8 — Strong Security

| Layer | Implementation |
|---|---|
| API abuse prevention | Firebase App Check (Play Integrity) |
| Firestore access control | `firestore.rules` — role + building scoped |
| Brute force protection | 5-attempt lockout (5 min) in `auth_provider.dart` |
| Password reset rate limit | 1 per 60 seconds in `auth_service.dart` |
| Email normalisation | `.toLowerCase()` before every auth call |
| Input sanitisation | HTML tag stripping in `firestore_service.dart` |
| HTTPS enforcement | `network_security_config.xml` |
| Backup disabled | `android:allowBackup="false"` in manifest |
| Broad storage removed | No `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` |
| Secure token storage | `flutter_secure_storage` available |
| FCM token cleanup | Token deleted from Firestore on sign-out |
| Role escalation blocked | Firestore rules block `role` field changes by users |

---

### ✅ Req 9 — SQL → Firebase Mapping

| SQL Table | Firestore Collection | Notes |
|---|---|---|
| `buildings` | `buildings` | ✅ |
| `complaint` | `complaints` | ✅ |
| `complaint_comments` | `complaint_comments` | ⚠️ **Add this to app — missing from original** |
| `flat` | `flats` | ✅ |
| `parking` | `parking` | ✅ |
| `services` | `services` | ✅ |
| `service_requests` | `service_requests` | ✅ |
| `users` | `users` | ✅ |
| `visitors` | `visitors` | ✅ |

---

### ✅ Req 10 — Android Studio + Flutter
- `compileSdk 35`, `minSdk 23`, `targetSdk 35`
- `coreLibraryDesugaringEnabled true` (Java 8 APIs on older Android)
- `jvmTarget = '17'`
- ProGuard rules cover all packages

---

## Build Commands

```bash
# Setup
flutter clean
flutter pub get

# Debug APK
flutter build apk --debug

# Release APK (requires key.properties — see below)
flutter build apk --release

# Deploy Firebase rules + indexes
firebase deploy --only firestore:rules,firestore:indexes
```

## Keystore Setup (Release Signing)
Create `android/key.properties` (DO NOT commit to git):
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=../your-keystore.jks
```

## New Client Onboarding Checklist
- [ ] Create Firebase project for client
- [ ] Download `google-services.json` → `android/app/`
- [ ] Edit `assets/config/saas_config.json`
- [ ] Change `applicationId` in `build.gradle`
- [ ] Deploy Firestore rules + indexes
- [ ] Enable App Check in Firebase Console → Play Integrity
- [ ] Create admin user in Firebase Auth → set `role: 'admin'` in Firestore
- [ ] Build and sign APK

## Files Added / Changed
```
ADDED:
  lib/core/saas_config.dart
  lib/shared/services/auth_provider.dart
  lib/shared/services/cache_service.dart
  lib/shared/services/connectivity_service.dart
  assets/config/saas_config.json
  firestore.rules
  firestore.indexes.json
  android/app/src/main/res/xml/network_security_config.xml

CHANGED:
  lib/main.dart
  lib/core/router.dart
  lib/shared/services/auth_service.dart
  lib/shared/services/firestore_service.dart
  lib/shared/services/notification_service.dart
  lib/shared/models/app_user.dart
  lib/shared/widgets/app_widgets.dart
  lib/features/auth/login_screen.dart
  lib/features/admin/admin_shell.dart
  lib/features/admin/admin_dashboard_screen.dart
  android/app/build.gradle
  android/app/proguard-rules.pro
  android/app/src/main/AndroidManifest.xml
  pubspec.yaml
```
