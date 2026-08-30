# Nudgr release minification rules.
# Flutter plugins ship their own consumer ProGuard rules (Firebase, BLE,
# notifications, etc.); the keeps below cover engine/plugin reflection paths
# not covered by those.

# Flutter engine <-> Dart plugin registration uses reflection.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Services / Firebase warnings are safe to suppress here.
-dontwarn com.google.**
-dontwarn javax.annotation.**

# Keep source file + line numbers for readable crash traces.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
