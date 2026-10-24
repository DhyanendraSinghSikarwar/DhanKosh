# R8 rules for the release build (found by the CI "Release APK builds" job).

# Optional classes referenced but not shipped: PDFBox's JPEG2000 decoder and
# ML Kit's non-Latin text recognisers (only Latin is used).
-dontwarn com.gemalto.jp2.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# PDFBox-Android loads fonts, filters and glyph lists by name; keep it whole so
# a statement that opens in debug also opens in release.
-keep class com.tom_roush.pdfbox.** { *; }
-keep class com.tom_roush.fontbox.** { *; }
