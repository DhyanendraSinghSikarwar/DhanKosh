package com.hisaab.sms

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture

/** Runs one Dart background task in a headless engine, then reports the result. */
class HeadlessWorker(
    context: Context,
    params: WorkerParameters,
) : ListenableWorker(context, params) {
    @Volatile
    private var job: HeadlessRunner.Job? = null

    override fun startWork(): ListenableFuture<Result> =
        CallbackToFutureAdapter.getFuture { completer ->
            val task = inputData.getString(BackgroundScheduler.KEY_TASK)
            if (task == null) {
                completer.set(Result.failure())
            } else {
                Handler(Looper.getMainLooper()).post {
                    job = HeadlessRunner.run(applicationContext, task) { ok ->
                        completer.set(
                            when {
                                ok -> Result.success()
                                runAttemptCount < MAX_ATTEMPTS -> Result.retry()
                                else -> Result.failure()
                            },
                        )
                    }
                }
            }
            "HeadlessWorker:" + task
        }

    override fun onStopped() {
        val running = job
        if (running != null) Handler(Looper.getMainLooper()).post { running.abort() }
    }

    private companion object {
        const val MAX_ATTEMPTS = 3
    }
}
