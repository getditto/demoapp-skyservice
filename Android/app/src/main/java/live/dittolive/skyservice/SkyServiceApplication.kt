package live.dittolive.skyservice

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import io.reactivex.rxjava3.core.Observable
import live.ditto.*
import live.ditto.android.DefaultAndroidDittoDependencies
import live.ditto.transports.DittoTransportConfig
import java.io.File

class SkyServiceApplication: Application() {

    companion object {
        var context: Context? = null
        var ditto: Ditto? = null

        fun startSyncing() {
            val workspaceId = DataService.workspaceId ?: return
            ditto?.startSync()
            DataService.setupSubscriptions(workspaceId)
        }
    }

    override fun onCreate() {
        super.onCreate()
        context = this
        val dependencies = DefaultAndroidDittoDependencies(this)
        val persistanceDir = "${(context as SkyServiceApplication).filesDir}/ditto-skyservice"
        dependencies.ensureDirectoryExists(persistanceDir)
        ditto = Ditto(
            dependencies,
            DittoIdentity.OnlineWithAuthentication(
                dependencies,
                BuildConfig.DITTO_APP_ID,
                AuthCallback(),
                true
            )
        )
        DittoLogger.minimumLogLevel = DittoLogLevel.DEBUG
        val name = getString(R.string.notification_key)
        val descriptionText = getString(R.string.notification_description)
        val importance = NotificationManager.IMPORTANCE_DEFAULT
        val channel = NotificationChannel("ditto.live.skyservice", name, importance).apply {
            description = descriptionText
        }
        // Register the channel with the system
        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }
}
class AuthCallback: DittoAuthenticationCallback {
    override fun authenticationRequired(authenticator: DittoAuthenticator) {
        authenticator.loginWithToken(BuildConfig.DITTO_AUTH_TOKEN, BuildConfig.DITTO_AUTH_PROVIDER) { err ->
            println("Login request completed. Error? $err")
        }
    }

    override fun authenticationExpiringSoon(
        authenticator: DittoAuthenticator,
        secondsRemaining: Long
    ) {
        authenticator.loginWithToken(BuildConfig.DITTO_AUTH_TOKEN, BuildConfig.DITTO_AUTH_PROVIDER) { err ->
            println("Login request completed. Error? $err")
        }
    }
}
