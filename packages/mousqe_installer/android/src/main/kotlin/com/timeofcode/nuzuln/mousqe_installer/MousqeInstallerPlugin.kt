package com.timeofcode.nuzuln.mousqe_installer

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Hands an APK the app downloaded to the system installer.
 *
 * The app downloads and verifies the file itself (Dart); this side only answers whether the
 * app may ask to install packages, opens that setting, and starts the installer. Android shows
 * its own confirmation: an app installed outside a store cannot update itself silently.
 */
class MousqeInstallerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val context = context ?: return result.error("NO_CONTEXT", "The plugin is not attached.", null)

        when (call.method) {
            "canInstall" -> result.success(canInstall(context))
            "openInstallSettings" -> result.success(openInstallSettings(context))
            "install" -> {
                val path = call.argument<String>("path")
                    ?: return result.error("BAD_ARGS", "No file path.", null)
                try {
                    install(context, File(path))
                    result.success(true)
                } catch (error: Exception) {
                    result.error("INSTALL_FAILED", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Android 8+ asks per app ("install unknown apps"); older versions ask in the installer itself. */
    private fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    private fun openInstallSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false

        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${context.packageName}"),
        )

        return start(context, intent)
    }

    private fun install(context: Context, file: File) {
        require(file.exists()) { "The update file is missing: ${file.path}" }

        val uri = FileProvider.getUriForFile(context, "${context.packageName}.mousqe_installer", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        if (!start(context, intent)) {
            throw IllegalStateException("No installer can open the update.")
        }
    }

    /** From the activity when there is one, so the installer opens on top of the app. */
    private fun start(context: Context, intent: Intent): Boolean {
        val host = activity
        if (host == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        return try {
            (host ?: context).startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    private companion object {
        const val CHANNEL = "com.timeofcode.nuzuln/installer"
    }
}
