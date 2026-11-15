package com.cruefan94.recipe_haven

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android Sharesheet receiver. Only HTTPS text URLs are accepted.
 * Nothing is saved automatically: the Dart app opens Add Recipe for review.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "recipe_haven/shared_recipe"
    private var shareChannel: MethodChannel? = null
    private var pendingUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Capture cold-start shares before Flutter Dart startup asks for them.
        receiveShare(intent, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, channelName
        )
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitialShare" -> {
                    val incoming = pendingUrl
                    pendingUrl = null
                    result.success(incoming)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveShare(intent, true)
    }

    private fun receiveShare(incoming: Intent?, deliverToFlutter: Boolean) {
        if (incoming?.action != Intent.ACTION_SEND ||
            incoming.type?.startsWith("text/plain") != true) return

        val sharedText = incoming.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?.toString()?.trim() ?: return
        if (sharedText.length > 12000) return

        // Android browsers often share title + newline + URL.
        val match = Regex("""https://[^\s<>"']+""").find(sharedText) ?: return
        val url = match.value.trimEnd('.', ',', ')', ']', '}')
        if (url.length > 2048) return

        val parsed = Uri.parse(url)
        if (parsed.scheme != "https" || parsed.host.isNullOrBlank() ||
            parsed.userInfo != null) return

        pendingUrl = url
        if (!deliverToFlutter) return

        shareChannel?.invokeMethod("sharedRecipeUrl", url, object : MethodChannel.Result {
            override fun success(result: Any?) {
                // Dart acknowledged receipt; avoid replay on a future launch.
                if (pendingUrl == url) pendingUrl = null
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                // Keep the pending URL if Flutter is temporarily unavailable.
            }
            override fun notImplemented() {
                // Keep the pending URL as a fallback.
            }
        })
    }
}
