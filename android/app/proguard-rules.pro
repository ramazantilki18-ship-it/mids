# Flutter & Plugin Proguard Rules

# Flutter Core & Plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Native Plugins (Geolocator, SQLite, NFC, Plus Plugins, OTA)
-keep class com.baseflow.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.tekartik.** { *; }
-keep class sk.fourq.otaupdate.** { *; }
-keep class io.flutter.plugins.nfc_manager.** { *; }
-keep class io.flutter.plugins.nfcmanager.** { *; }

# Warnings
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn org.codehaus.mojo.animalsniffer.**
-dontwarn com.google.android.play.core.**
