package com.hisaab.hisaab

import com.hisaab.notifications.NotificationsBridge
import com.hisaab.sms.SmsBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsBridge: SmsBridge? = null
    private var notificationsBridge: NotificationsBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = SmsBridge(this).also { it.attach(flutterEngine.dartExecutor.binaryMessenger) }
        notificationsBridge = NotificationsBridge(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        smsBridge?.detach()
        smsBridge = null
        notificationsBridge?.detach()
        notificationsBridge = null
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
