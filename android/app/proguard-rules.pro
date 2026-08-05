# android/app/proguard-rules.pro
# ─────────────────────────────────────────────────────────────────────────────
# Full ProGuard/R8 rules for ApartmentApp
# Applied in release builds (minifyEnabled true)
# ─────────────────────────────────────────────────────────────────────────────

# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Firebase ──────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase App Check ────────────────────────────────────────────────────────
-keep class com.google.firebase.appcheck.** { *; }

# ── Firestore model serialization ────────────────────────────────────────────
# Keep data classes used in Firestore toMap/fromDoc
-keepclassmembers class * {
    @com.google.firebase.firestore.IgnoreExtraProperties *;
}

# ── Kotlin ────────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ── Hive ──────────────────────────────────────────────────────────────────────
-keep class com.hive.** { *; }
-keep @io.hive.annotation.HiveType class * { *; }
-keep @io.hive.annotation.HiveField class * { *; }

# ── flutter_secure_storage ────────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── shared_preferences ───────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── connectivity_plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── local_auth ────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }

# ── image_picker ──────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ── firebase_messaging ────────────────────────────────────────────────────────
-keep class com.google.firebase.messaging.** { *; }
-keepclassmembers class com.google.firebase.messaging.FirebaseMessagingService {
    public void onMessageReceived(com.google.firebase.messaging.RemoteMessage);
    public void onNewToken(java.lang.String);
}

# ── Prevent obfuscating crash reporting (keeps readable stack traces) ─────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Remove debug logging in release ──────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# ── Keep annotation types ─────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
