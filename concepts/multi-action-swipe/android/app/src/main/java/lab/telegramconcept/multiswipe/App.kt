package lab.telegramconcept.multiswipe

import android.app.Application

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        SwipeConfig.init(this)
    }
}
