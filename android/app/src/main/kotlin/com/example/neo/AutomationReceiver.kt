package com.example.neo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

class AutomationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val routineId = intent.getIntExtra("routineId", -1)
        val routineName = intent.getStringExtra("routineName") ?: "Routine"
        
        Log.d("AutomationReceiver", "Received alarm for routine: $routineId ($routineName)")
        
        if (routineId == -1) return

        // Wake up the screen if needed
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "Neo:AutomationWakeLock"
        )
        wakeLock.acquire(10000) // 10 seconds

        // Launch the app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        launchIntent?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("routineId", routineId)
            putExtra("source", "automation_trigger")
            context.startActivity(this)
        }
    }
}
