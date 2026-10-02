# Gson — preserva TypeToken e reflexão de tipos genéricos
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# flutter_notification_listener
-keep class com.github.fengyie007.** { *; }
-keep class androidx.core.app.** { *; }

# Supabase / Ktor / OkHttp
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Geral — mantém classes com generics
-keepattributes InnerClasses
-keepattributes EnclosingMethod
