package com.example.secure_trace

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class MyDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        // Device Admin privileges successfully grabbed
        super.onEnabled(context, intent)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        // Device Admin revoked
        super.onDisabled(context, intent)
    }

    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        val prefs = context.getSharedPreferences("SecureTracePrefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("intruder_detected", true).apply()
    }
}
