# Flutter Proguard Rules

# Keep Flutter Common Classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Keep Firebase classes to prevent auth/firestore issues
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Core (Deferred Components / Dynamic Feature) uyarilarini gec
-dontwarn com.google.android.play.core.**

# Keep standard classes
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn org.codehaus.mojo.animalsniffer.**
