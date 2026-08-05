#!/bin/bash
# scripts/onboard_client.sh
#
# Automated SaaS client onboarding
# Usage: ./scripts/onboard_client.sh "Royal Residence" "#B8860B" "admin@royal.com"

set -e

CLIENT_NAME="${1:-NewClient}"
ACCENT_COLOR="${2:-#00BCD4}"
ADMIN_EMAIL="${3:-admin@example.com}"

# Sanitize for app ID (lowercase, no spaces)
APP_ID=$(echo "$CLIENT_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ' | tr -d '-')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Onboarding: $CLIENT_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Create Firebase project
echo "📦 Step 1/6: Creating Firebase project..."
firebase projects:create "ams-$APP_ID" --display-name "$CLIENT_NAME AMS" || true
firebase use "ams-$APP_ID"

# 2. Enable required services
echo "🔥 Step 2/6: Enabling Firebase services..."
firebase apps:create ANDROID "com.ams.$APP_ID" --project "ams-$APP_ID"
# Download google-services.json automatically via Firebase CLI
firebase apps:sdkconfig ANDROID --out android/app/google-services.json

# 3. Update saas_config.json
echo "🎨 Step 3/6: Updating SaaS config..."
cat > assets/config/saas_config.json <<EOF
{
  "appName": "$CLIENT_NAME AMS",
  "tagline": "Your home, simplified",
  "buildingNameDefault": "$CLIENT_NAME",
  "adminEmail": "$ADMIN_EMAIL",
  "primaryColorHex": "#1A2B4A",
  "accentColorHex": "$ACCENT_COLOR",
  "allowSelfSignup": true,
  "supportEmail": "$ADMIN_EMAIL",
  "privacyPolicyUrl": "https://yourcompany.com/privacy"
}
EOF

# 4. Update applicationId
echo "📝 Step 4/6: Updating application ID..."
sed -i.bak "s/applicationId \"com\.example\.apartment_app\"/applicationId \"com.ams.$APP_ID\"/" android/app/build.gradle
sed -i.bak "s/namespace \"com\.example\.apartment_app\"/namespace \"com.ams.$APP_ID\"/" android/app/build.gradle

# 5. Deploy Firestore rules
echo "🔒 Step 5/6: Deploying Firestore rules..."
firebase deploy --only firestore:rules,firestore:indexes --project "ams-$APP_ID"

# 6. Build APK
echo "🔨 Step 6/6: Building release APK..."
flutter clean
flutter pub get
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
OUTPUT_NAME="${CLIENT_NAME// /_}_v1.0.0.apk"

cp "$APK_PATH" "releases/$OUTPUT_NAME"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SUCCESS!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 APK: releases/$OUTPUT_NAME"
echo "🔑 App ID: com.ams.$APP_ID"
echo "🔥 Firebase: ams-$APP_ID"
echo ""
echo "Next steps:"
echo "1. Create admin user in Firebase Auth"
echo "2. Set role='admin' in Firestore users collection"
echo "3. Upload APK to Play Store"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
