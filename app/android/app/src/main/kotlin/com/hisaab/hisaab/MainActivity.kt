package com.hisaab.hisaab

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import com.hisaab.alerts.AlertsBridge
import com.hisaab.notifications.NotificationsBridge
import com.hisaab.pdf.PdfBridge
import com.hisaab.sms.SmsBridge
import com.hisaab.widget.WidgetBridge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var smsBridge: SmsBridge? = null
    private var notificationsBridge: NotificationsBridge? = null
    private var pdfBridge: PdfBridge? = null
    private var alertsBridge: AlertsBridge? = null
    private var widgetBridge: WidgetBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Apply the saved choice before the first frame (FR-25-19).
        val secure = getSharedPreferences(AlertsBridge.WINDOW_PREFS, Context.MODE_PRIVATE)
            .getBoolean(AlertsBridge.KEY_SECURE, false)
        applySecure(secure)
    }

    private fun applySecure(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = SmsBridge(this).also { it.attach(flutterEngine.dartExecutor.binaryMessenger) }
        notificationsBridge = NotificationsBridge(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
        pdfBridge = PdfBridge(this).also { it.attach(flutterEngine.dartExecutor.binaryMessenger) }
        alertsBridge = AlertsBridge(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
        widgetBridge = WidgetBridge(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
        AlertsBridge.secureHandler = { on -> runOnUiThread { applySecure(on) } }
        AlertsBridge.captureRoute(intent)
        AlertsBridge.captureShared(this, intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        AlertsBridge.captureRoute(intent)
        AlertsBridge.captureShared(this, intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        AlertsBridge.secureHandler = null
        smsBridge?.detach()
        smsBridge = null
        notificationsBridge?.detach()
        notificationsBridge = null
        pdfBridge?.detach()
        pdfBridge = null
        alertsBridge?.detach()
        alertsBridge = null
        widgetBridge?.detach()
        widgetBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsBridge?.onPermissionResult(requestCode)
    }
}
