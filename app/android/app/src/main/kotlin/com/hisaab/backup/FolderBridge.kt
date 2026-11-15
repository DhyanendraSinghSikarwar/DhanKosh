package com.hisaab.backup

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel `backup_folder` (memory 24): a folder the user chose with
 * the system folder picker, on the phone or in a cloud provider such as
 * Google Drive. No account or token is handled here; the system provider owns
 * the sign-in. Works with an application context so the background job can
 * write too. Never logs file names or contents.
 */
class FolderBridge(context: Context) {
    private val app: Context = context.applicationContext
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.hisaab/backup_folder").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pick" -> {
                    val launcher = picker
                    if (launcher == null) {
                        result.error("unavailable", "No screen to pick a folder", null)
                    } else {
                        launcher { uri -> result.success(describe(uri)) }
                    }
                }
                "canWrite" -> result.success(canWrite(call.argument<String>("uri")))
                "list" -> result.success(list(call.argument<String>("uri")))
                "write" -> {
                    write(
                        call.argument<String>("uri"),
                        call.argument<String>("name"),
                        call.argument<ByteArray>("bytes"),
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("folder_failed", e.javaClass.simpleName, null)
        }
    }

    private fun tree(uri: String?): DocumentFile? =
        uri?.let { DocumentFile.fromTreeUri(app, Uri.parse(it)) }

    private fun describe(uri: Uri?): Map<String, String>? {
        if (uri == null) return null
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        app.contentResolver.takePersistableUriPermission(uri, flags)
        val doc = DocumentFile.fromTreeUri(app, uri)
        val provider = when {
            uri.authority?.contains("google.android.apps.docs") == true -> "Google Drive"
            uri.authority == "com.android.externalstorage.documents" -> "This phone"
            else -> uri.authority ?: ""
        }
        return mapOf("uri" to uri.toString(), "name" to (doc?.name ?: ""), "provider" to provider)
    }

    private fun canWrite(uri: String?): Boolean = tree(uri)?.canWrite() ?: false

    private fun list(uri: String?): List<String> =
        tree(uri)?.listFiles()?.mapNotNull { it.name } ?: emptyList()

    private fun write(uri: String?, name: String?, bytes: ByteArray?) {
        val dir = tree(uri) ?: throw IllegalStateException("no folder")
        if (name == null || bytes == null) throw IllegalArgumentException("args")
        val existing = dir.findFile(name)
        val target = existing ?: dir.createFile("application/octet-stream", name)
            ?: throw IllegalStateException("create")
        app.contentResolver.openOutputStream(target.uri, "wt")?.use { it.write(bytes) }
            ?: throw IllegalStateException("open")
    }

    companion object {
        /** Set by MainActivity: opens the system folder picker, then calls back. */
        @Volatile
        var picker: (((Uri?) -> Unit) -> Unit)? = null
    }
}
