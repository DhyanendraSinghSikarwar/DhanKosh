package com.hisaab.sms

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.hisaab.alerts.AlertsBridge
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Starts a FlutterEngine without an Activity and runs the Dart `callbackDispatcher`
 * (lib/app/background/background_dispatcher.dart). Dart asks for its task over
 * `com.hisaab/background`, runs it and calls `done`, which destroys the engine.
 * Call [run] on the main thread.
 */
object HeadlessRunner {
    private const val ENTRY_LIBRARY = "package:hisaab/app/background/background_dispatcher.dart"
    private const val ENTRY_FUNCTION = "callbackDispatcher"
    private const val TIMEOUT_MS = 9 * 60 * 1000L

    class Job internal constructor(private val onDone: (Boolean) -> Unit) {
        internal var engine: FlutterEngine? = null
        private var finished = false

        val isFinished: Boolean get() = finished

        /** Main thread. Destroys the engine and reports once. */
        fun finish(ok: Boolean) {
            if (finished) return
            finished = true
            engine?.destroy()
            engine = null
            onDone(ok)
        }

        fun abort() = finish(false)
    }

    fun run(context: Context, task: String, onDone: (Boolean) -> Unit): Job {
        val app = context.applicationContext
        val main = Handler(Looper.getMainLooper())
        val job = Job(onDone)
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) loader.startInitialization(app)
        loader.ensureInitializationCompleteAsync(app, null, main) {
            if (job.isFinished) return@ensureInitializationCompleteAsync
            val engine = FlutterEngine(app)
            job.engine = engine
            val messenger = engine.dartExecutor.binaryMessenger
            // Not detached: the engine is destroyed, and detaching would clear the UI sink.
            SmsChannels(app).attach(messenger, withLive = false)
            AlertsBridge(app).attach(messenger)
            BackgroundBridge(app, task) { ok -> main.post { job.finish(ok) } }.attach(messenger)
            main.postDelayed({ job.finish(false) }, TIMEOUT_MS)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRY_LIBRARY, ENTRY_FUNCTION),
            )
        }
        return job
    }
}
