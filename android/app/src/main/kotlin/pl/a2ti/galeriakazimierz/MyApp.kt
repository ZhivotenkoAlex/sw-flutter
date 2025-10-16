package pl.a2ti.galeriakazimierz

import android.app.Application
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import pl.a2ti.galeriakazimierz.R

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
