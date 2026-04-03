package com.example.secure_trace

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.secure_trace/device_admin"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var componentName: ComponentName

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAdmin" -> {
                    if (!devicePolicyManager.isAdminActive(componentName)) {
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                        intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "SecureTrace requires Device Admin privileges to remotely lock or wipe your lost phone to protect your data.")
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true) 
                    }
                }
                "removeAdmin" -> {
                    devicePolicyManager.removeActiveAdmin(componentName)
                    result.success(true)
                }
                "isAdminActive" -> {
                    result.success(devicePolicyManager.isAdminActive(componentName))
                }
                "lockDevice" -> {
                    if (devicePolicyManager.isAdminActive(componentName)) {
                        devicePolicyManager.lockNow()
                        result.success(true)
                    } else {
                        result.error("NOT_ADMIN", "Device admin permissions not granted.", null)
                    }
                }
                "checkIntruder" -> {
                    val prefs = applicationContext.getSharedPreferences("SecureTracePrefs", Context.MODE_PRIVATE)
                    val intruder = prefs.getBoolean("intruder_detected", false)
                    if (intruder) {
                        prefs.edit().putBoolean("intruder_detected", false).apply()
                    }
                    result.success(intruder)
                }
                "checkSimState" -> {
                    if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                            val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                            val activeSubscriptionInfoList = subManager.activeSubscriptionInfoList
                            if (activeSubscriptionInfoList != null && activeSubscriptionInfoList.isNotEmpty()) {
                                val simData = activeSubscriptionInfoList.joinToString(",") { info ->
                                    "${info.subscriptionId}_${info.carrierName}"
                                }
                                result.success(simData)
                            } else {
                                result.success("NO_SIM")
                            }
                        } else {
                            result.success("UNSUPPORTED_API")
                        }
                    } else {
                        result.error("PERMISSION_DENIED", "READ_PHONE_STATE not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
