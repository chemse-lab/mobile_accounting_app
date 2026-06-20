# قواعد ProGuard - تمنع حذف الأكواد المطلوبة من المكتبات أثناء التصغير في وضع release

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# Bluetooth (flutter_bluetooth_serial)
-keep class io.github.edufolly.fluttertts.** { *; }
-keepclassmembers class * extends android.bluetooth.** { *; }
