package com.skanujwygrywaj.skanuj_wygrywaj

import android.app.Application
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import com.skanujwygrywaj.skanuj_wygrywaj.R

class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            FacebookSdk.setApplicationId(getString(R.string.facebook_app_id))
            FacebookSdk.setAutoInitEnabled(true)
            FacebookSdk.sdkInitialize(applicationContext)
            FacebookSdk.fullyInitialize()
            AppEventsLogger.activateApp(this)
        } catch (_: Throwable) { }
    }
}
