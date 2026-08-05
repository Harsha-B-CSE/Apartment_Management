# ApartmentApp – SaaS Apartment Management System

A **Flutter + Firebase** based **Apartment Management System (AMS)** designed for **Android** with **multi-building SaaS support**. The application enables apartment administrators and tenants to manage apartments, complaints, visitors, parking, services, notifications, and more through secure role-based access.

---

## ✨ Features

### 👨‍💼 Admin

- Dashboard
- Building Management
- Flat Management
- Member Management
- Complaint Management
- Visitor Management
- Parking Management
- Services Management
- Service Requests
- Notifications
- Profile Management

### 👨‍👩‍👧 Tenant

- Dashboard
- My Complaints
- My Visitors
- My Parking
- Service Requests
- Notifications
- Profile Management

---

## 🛠 Technology Stack

### Frontend

- Flutter
- Dart

### Backend

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging (FCM)
- Firebase App Check

### Local Storage

- Hive

---

## 🚀 Key Features

### Android Optimized

- Android-only application
- Material Design UI
- Responsive Layout
- Portrait Orientation Lock

### Performance

- Hive Local Cache
- Offline Support
- Retry Mechanism
- Firestore Pagination
- Dashboard Cache
- Shimmer Loading
- Responsive Navigation

### Security

- Firebase Authentication
- Firebase App Check
- Firestore Security Rules
- Role-Based Access Control
- Secure Token Storage
- Login Attempt Lockout
- Password Reset Rate Limiting
- HTTPS Enforcement
- Android Backup Disabled

### SaaS Support

- Multi-Building Architecture
- White-Label Configuration
- Client-Specific Branding
- Remote Configuration
- Firebase Project Isolation

---

# 📂 Project Structure

```text
lib/
├── core/
├── features/
│   ├── admin/
│   ├── auth/
│   ├── guard/
│   └── member/
├── shared/
│   ├── models/
│   ├── services/
│   ├── utils/
│   └── widgets/
├── assets/
└── main.dart
```

---

# ⚙️ Firebase Configuration

This repository **does not include Firebase configuration files**.

Every developer or client must configure Firebase using their own Firebase project.

## 1. Create a Firebase Project

Enable the following services:

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging (FCM)
- Firebase App Check

---

## 2. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

---

## 3. Generate Firebase Configuration

```bash
flutterfire configure
```

This command automatically generates:

```
lib/firebase_options.dart
```

---

## 4. Download Android Configuration

Download

```
google-services.json
```

from the Firebase Console and place it in:

```
android/app/google-services.json
```

---

## 5. Install Dependencies

```bash
flutter pub get
```

---

## 6. Deploy Firestore Rules & Indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

---

# 🔒 Files Not Included

The following files are intentionally **excluded** from this repository because they contain project-specific or sensitive information.

| File | Description |
|------|-------------|
| `android/app/google-services.json` | Firebase Android configuration |
| `lib/firebase_options.dart` | Generated using `flutterfire configure` |
| `android/key.properties` | Android release signing configuration |
| `*.jks` | Android signing key |
| `*.keystore` | Android signing key |
| `.env` | Environment variables |
| `serviceAccountKey.json` | Firebase Admin SDK credentials |

> Generate or provide your own copies of these files before building the application.

---

# 🚀 Installation

Clone the repository

```bash
git clone https://github.com/Harsha-B-CSE/Apartment_Management.git
```

Navigate to the project

```bash
cd Apartment_Management
```

Clean the project

```bash
flutter clean
```

Install dependencies

```bash
flutter pub get
```

Run the application

```bash
flutter run
```

---

# 📦 Build APK

### Debug

```bash
flutter build apk --debug
```

### Release

```bash
flutter build apk --release
```

---

# ☁️ Firebase Deployment

Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

Deploy Everything

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

---

# 🔑 Release Signing

Create

```
android/key.properties
```

Example

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=../your-keystore.jks
```

> **Never commit** `key.properties`, `.jks`, or `.keystore` files to GitHub.

---

# 🏢 New Client Setup

1. Create a Firebase Project.
2. Download `google-services.json`.
3. Copy it to `android/app/`.
4. Run `flutterfire configure`.
5. Edit `assets/config/saas_config.json`.
6. Change the Android package name.
7. Deploy Firestore Rules and Indexes.
8. Enable Firebase App Check.
9. Create an Administrator account.
10. Build and sign the APK.

---

# 🗄 Firestore Collections

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

# 📋 Major Improvements

### Performance

- Hive Local Caching
- Offline Mode
- Firestore Pagination
- Retry Mechanism
- Dashboard Cache
- Shimmer Loading
- Responsive Navigation

### Security

- Firebase App Check
- Firestore Security Rules
- Role-Based Authorization
- Login Lockout
- Password Reset Rate Limiting
- Secure Storage
- HTTPS Enforcement

### SaaS

- Multi-Tenant Architecture
- White-Label Support
- Remote Configuration
- Client Branding

---

# 🛡 Security

- Firebase Authentication
- Firebase App Check
- Firestore Security Rules
- Secure Local Storage
- Network Security Configuration
- Role-Based Access Control
- Login Attempt Protection
- Password Reset Protection

---

# 📸 Screenshots

Add screenshots of the application here.

Example:

```
screenshots/
├── login.png
├── admin_dashboard.png
├── member_dashboard.png
├── complaints.png
├── visitors.png
├── parking.png
└── notifications.png
```

---

# 🤝 Contributing

1. Fork the repository.
2. Create a new feature branch.

```bash
git checkout -b feature-name
```

3. Commit your changes.

```bash
git commit -m "Add new feature"
```

4. Push your branch.

```bash
git push origin feature-name
```

5. Open a Pull Request.

---

# 📄 License

This project was developed for **educational and demonstration purposes**.

---

# 👨‍💻 Author

**Harsha B**

- GitHub: https://github.com/Harsha-B-CSE

---

⭐ **If you found this project helpful, please consider giving it a star on GitHub.**
