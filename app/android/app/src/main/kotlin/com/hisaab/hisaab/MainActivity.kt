package com.hisaab.hisaab

import android.content.Intent
import com.hisaab.alerts.AlertsBridge
import com.hisaab.notifications.NotificationsBridge
import com.hisaab.pdf.PdfBridge
import com.hisaab.sms.SmsBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsBridge: SmsBridge? = null
    private var notificationsBridge: NotificationsBridge? = null
    private var pdfBridge: PdfBridge? = null
    private var alertsBridge: AlertsBridge? = null

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
        AlertsBridge.captureRoute(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        AlertsBridge.captureRoute(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        smsBridge?.detach()
        smsBridge = null
        notificationsBridge?.detach()
        notificationsBridge = null
        pdfBridge?.detach()
        pdfBridge = null
        alertsBridge?.detach()
        alertsBridge = null
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
