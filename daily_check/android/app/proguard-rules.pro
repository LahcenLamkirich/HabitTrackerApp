# flutter_local_notifications serialises scheduled-notification details with
# Gson, which relies on reflection. Without these rules R8 strips the generic
# signatures and the plugin fails to restore notifications after a reboot.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Gson internals used by the plugin above.
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
