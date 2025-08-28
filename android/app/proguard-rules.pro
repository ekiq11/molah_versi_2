# ✅ SOLUSI: Keep url_launcher classes
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# Keep MMKV
-keep class com.tencent.mmkv.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ✅ PENTING: Keep Android Intent dan URL launcher related classes
-keep class android.content.Intent { *; }
-keep class android.net.Uri { *; }
-keep class android.content.pm.** { *; }

# Keep Google Play Core (untuk mengatasi error R8)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep your app classes
-keep class com.example.molahv2.** { *; }

# ✅ TAMBAHAN: Keep WebView dan Browser related (untuk wa.me links)
-keep class android.webkit.** { *; }
-keep class androidx.browser.** { *; }
-dontwarn androidx.browser.**

# ✅ Keep classes untuk Custom Tabs
-keep class androidx.browser.customtabs.** { *; }

# ✅ Prevent obfuscation of URL schemes
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
# Keep WhatsApp intent
-keep class com.whatsapp.** { *; }
-dontwarn com.whatsapp.**

# Keep Pigeon generated classes (untuk komunikasi Flutter-Android)
-keep class dev.flutter.pigeon.** { *; }

# Keep MethodChannel related
-keep class io.flutter.plugin.common.** { *; }

# Keep untuk error handling yang lebih baik
-keep class java.lang.reflect.** { *; }