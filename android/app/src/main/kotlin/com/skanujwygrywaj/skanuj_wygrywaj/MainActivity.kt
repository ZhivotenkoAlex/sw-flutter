package com.skanujwygrywaj.skanuj_wygrywaj

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.CallbackManager
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import com.skanujwygrywaj.skanuj_wygrywaj.R
import android.util.Log

class MainActivity : FlutterFragmentActivity() {
    private lateinit var callbackManager: CallbackManager
    private val TAG = "FBInit"

    private fun ensureFacebookInitialized() {
        try {
            Log.d(TAG, "ensureFacebookInitialized() start")
            val appId = getString(R.string.facebook_app_id)
            FacebookSdk.setApplicationId(appId)
            FacebookSdk.setAutoInitEnabled(true)
            if (!FacebookSdk.isInitialized()) {
                FacebookSdk.sdkInitialize(applicationContext)
                Log.d(TAG, "sdkInitialize() called")
            }
            FacebookSdk.fullyInitialize()
            AppEventsLogger.activateApp(application)
            Log.d(TAG, "ensureFacebookInitialized() finished")
        } catch (t: Throwable) {
            Log.e(TAG, "ensureFacebookInitialized error: ${t.message}")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize early (no getter logs)
        ensureFacebookInitialized()
        callbackManager = CallbackManager.Factory.create()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fb_fallback").setMethodCallHandler { call, result ->
            if (call.method == "login") {
                try {
                    ensureFacebookInitialized()
                    val loginManager = LoginManager.getInstance()
                    // Ensure fresh
                    try { loginManager.logOut() } catch (_: Throwable) {}
                    loginManager.registerCallback(callbackManager, object : FacebookCallback<LoginResult> {
                        override fun onSuccess(loginResult: LoginResult) {
                            val token = loginResult.accessToken?.token ?: ""
                            val userId = loginResult.accessToken?.userId ?: ""
                            val expiresIn = loginResult.accessToken?.expires?.time?.let { ((it - System.currentTimeMillis()) / 1000).toInt() }
                            val map = hashMapOf<String, Any?>(
                                "accessToken" to token,
                                "userId" to userId,
                                "expiresIn" to expiresIn
                            )
                            Log.d(TAG, "login success tokenLen=${token.length} userId=$userId")
                            result.success(map)
                        }
                        override fun onCancel() {
                            Log.d(TAG, "login cancel")
                            result.success(hashMapOf("error" to "cancel"))
                        }
                        override fun onError(error: FacebookException) {
                            Log.e(TAG, "login error: ${error.message}")
                            result.success(hashMapOf("error" to (error.message ?: "unknown")))
                        }
                    })
                    loginManager.logIn(this@MainActivity, listOf("email", "public_profile"))
                } catch (e: Throwable) {
                    Log.e(TAG, "fb_fallback login throwable: ${e.message}")
                    result.success(hashMapOf("error" to (e.message ?: "unknown")))
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::callbackManager.isInitialized) {
            callbackManager.onActivityResult(requestCode, resultCode, data)
        }
    }
}
