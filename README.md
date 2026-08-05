# ApartmentApp – Upgraded SaaS Apartment Management System

A Flutter + Firebase based Apartment Management System (AMS) designed for Android with multi-building SaaS support. The application enables apartment administrators and tenants to manage buildings, complaints, visitors, parking, services, and notifications through secure role-based access.

---

## Features

### Admin
- Dashboard
- Building Management
- Flat Management
- Member Management
- Complaint Management
- Visitor Management
- Parking Management
- Services
- Service Requests
- Notifications
- Profile

### Tenant
- Dashboard
- My Complaints
- My Visitors
- My Parking
- Service Requests
- Notifications
- Profile

---

## Technology Stack

### Frontend
- Flutter
- Dart

### Backend
- Firebase Authentication
- Cloud Firestore
- Firebase App Check
- Firebase Cloud Messaging

### Local Storage
- Hive

---

## Major Improvements

### Android Only
- Removed iOS support
- Android optimized build

### Performance
- Hive caching
- Offline mode
- Retry mechanism
- Pagination
- Dashboard cache
- Shimmer loading
- Portrait lock

### Security
- Firebase App Check
- Firestore security rules
- Role-based authorization
- Login lockout
- Password reset rate limiting
- Secure token storage
- HTTPS enforcement
- Backup disabled

### SaaS Features
- Multi-building architecture
- White-label configuration
- Client-specific branding
- Remote configuration

---

## Project Setup

```bash
flutter clean
flutter pub get
```

Run

```bash
flutter run
```

---

## Build APK

Debug

```bash
flutter build apk --debug
```

Release

```bash
flutter build apk --release
```

---

## Firebase Deployment

Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

Or deploy both

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

---

## Release Signing

Create

```
android/key.properties
```

Example

```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=../your-keystore.jks
```

---

## New Client Setup

1. Create Firebase Project
2. Download google-services.json
3. Replace android/app/google-services.json
4. Edit assets/config/saas_config.json
5. Change Android package name
6. Deploy Firestore Rules
7. Enable Firebase App Check
8. Create Admin Account
9. Build Release APK

---

## Firestore Collections

- buildings
- users
- flats
- complaints
- complaint_comments
- visitors
- parking
- services
- service_requests

---

## Project Structure

```
lib/
 ├── core/
 ├── features/
 ├── shared/
 ├── models/
 ├── services/
 ├── widgets/
```

---

## Security

- Firebase Authentication
- Firestore Rules
- App Check
- Role-based Access
- Secure Storage
- Network Security Configuration

---

## License

This project is intended for educational and demonstration purposes.
