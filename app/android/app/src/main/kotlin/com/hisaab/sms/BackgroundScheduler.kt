package com.hisaab.sms

import android.content.Context
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/** WorkManager jobs that start the headless Dart engine (see [HeadlessWorker]). */
object BackgroundScheduler {
    const val KEY_TASK = "hisaab_task"
    const val TASK_SMS_DRAIN = "sms.drain"
    const val UNIQUE_SMS_DRAIN = "sms-live-drain"

    private fun data(task: String) = Data.Builder().putString(KEY_TASK, task).build()

    /**
     * One-off job. [replace] false appends after a running job, so a message that arrives
     * while a drain runs is picked up by the next one.
     */
    fun oneOff(context: Context, uniqueName: String, task: String, replace: Boolean) {
        val request = OneTimeWorkRequest.Builder(HeadlessWorker::class.java)
            .setInputData(data(task))
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            uniqueName,
            if (replace) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.APPEND_OR_REPLACE,
            request,
        )
    }

    /** Periodic job, no network constraint; an existing job of the same name is kept. */
    fun periodic(
        context: Context,
        uniqueName: String,
        task: String,
        intervalMinutes: Long,
        initialDelayMinutes: Long,
        requiresBatteryNotLow: Boolean,
    ) {
        val request = PeriodicWorkRequest.Builder(
            HeadlessWorker::class.java,
            intervalMinutes,
            TimeUnit.MINUTES,
        )
            .setInitialDelay(initialDelayMinutes, TimeUnit.MINUTES)
            .setConstraints(
                Constraints.Builder().setRequiresBatteryNotLow(requiresBatteryNotLow).build(),
            )
            .setInputData(data(task))
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            uniqueName,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    fun cancel(context: Context, uniqueName: String) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(uniqueName)
    }
}
