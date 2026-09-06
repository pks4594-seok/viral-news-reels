# Flutter 엔진
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# xml 파서 (petitparser 리플렉션)
-keep class org.xmlpull.** { *; }
-dontwarn org.xmlpull.**

# Hive / shared_preferences
-keep class androidx.** { *; }
-dontwarn androidx.**

# 일반 경고 억제
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
