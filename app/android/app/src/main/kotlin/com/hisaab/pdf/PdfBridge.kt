package com.hisaab.pdf

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Platform channel `pdf` (FR-05-02). `extractText{path | bytes, password?}` returns
 * `{text, pages}`; errors: `password_required`, `wrong_password`, `unreadable`, `scanned`.
 * Runs off the main thread. Text, passwords and paths are never logged.
 */
class PdfBridge(context: Context) {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        PDFBoxResourceLoader.init(appContext)
        channel = MethodChannel(messenger, "com.hisaab/pdf").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        worker.shutdown()
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "extractText") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        val bytes = call.argument<ByteArray>("bytes")
        val password = call.argument<String>("password")
        worker.execute {
            val reply = extract(path, bytes, password)
            main.post {
                if (reply.code == null) {
                    result.success(reply.value)
                } else {
                    result.error(reply.code, reply.message, null)
                }
            }
        }
    }

    private class Reply(val code: String?, val message: String?, val value: Any?)

    private fun extract(path: String?, bytes: ByteArray?, password: String?): Reply {
        val pass = password ?: ""
        if (bytes == null && path == null) return Reply("unreadable", "No input", null)
        return try {
            val doc = if (bytes != null) PDDocument.load(bytes, pass) else PDDocument.load(File(path!!), pass)
            try {
                val stripper = PDFTextStripper()
                stripper.sortByPosition = true
                val text = stripper.getText(doc)
                if (text.isBlank()) {
                    Reply("scanned", "No text layer", null)
                } else {
                    Reply(null, null, mapOf("text" to text, "pages" to doc.numberOfPages))
                }
            } finally {
                doc.close()
            }
        } catch (e: InvalidPasswordException) {
            Reply(if (pass.isEmpty()) "password_required" else "wrong_password", "Password needed", null)
        } catch (e: Exception) {
            Reply("unreadable", "Cannot read PDF", null)
        } catch (e: OutOfMemoryError) {
            Reply("unreadable", "Too large", null)
        }
    }
}
