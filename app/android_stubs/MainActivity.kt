package com.hisaab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Stub channel handlers. Every call returns notImplemented until the native
 * features (plan.md section 2, "Native (Kotlin)") are written.
 */
class MainActivity : FlutterActivity() {
    private val channels = listOf(
        "com.hisaab/sms",
        "com.hisaab/notifications",
        "com.hisaab/secure",
        "com.hisaab/pdf",
        "com.hisaab/widget",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        for (name in channels) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, name)
                .setMethodCallHandler { _, result -> result.notImplemented() }
        }
    }
}
