# Gson 反射模型（字段名依赖 @SerializedName）
-keep class com.example.dodroidai.ai.config.** { *; }
-keep class com.example.dodroidai.ai.model.** { *; }
-keep class com.example.dodroidai.data.model.** { *; }
-keep class com.example.dodroidai.ai.tools.** { *; }

# 保留 @SerializedName 注解
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# JNI（whisper）
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.example.dodroidai.ai.voice.** { *; }

# WebView JS Bridge
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.example.dodroidai.webviewsdk.** { *; }

# Android 组件（manifest 已引用，保留类名）
-keep class com.example.dodroidai.MainActivity { *; }
-keep class com.example.dodroidai.alarm.** { *; }
-keep class com.example.dodroidai.widget.** { *; }

# PDFBox 可选 JPEG2000 解码器（未打包，不影响文本抽取）
-dontwarn com.gemalto.jp2.**

# Gson TypeToken 泛型签名（AppConfigManager 的匿名 TypeToken 子类）
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
