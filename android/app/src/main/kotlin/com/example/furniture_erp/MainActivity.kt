package com.example.furniture_erp

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val UPDATER_CHANNEL = "com.example.furniture_erp/app_updater"
        private const val ALLOWED_RELEASE_URL_PREFIX = "https://github.com/emontal90/el-alfy-90/releases"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestPackageInstalls" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "openUnknownAppSourcesSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing APK path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = File(path)
                            val canonicalPath = file.canonicalPath
                            val internalUpdatesDir = File(cacheDir, "updates").canonicalPath + File.separator
                            val externalUpdatesDir = externalCacheDir?.let { File(it, "updates").canonicalPath + File.separator }
                            val inAllowedDir = canonicalPath.startsWith(internalUpdatesDir) ||
                                (externalUpdatesDir != null && canonicalPath.startsWith(externalUpdatesDir))

                            if (!inAllowedDir || !file.exists() || !file.isFile) {
                                result.error("INVALID_FILE", "APK file not found in updates cache", null)
                                return@setMethodCallHandler
                            }

                            val apkUri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(installIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message ?: "Failed to launch installer", null)
                        }
                    }
                    "openBrowserUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank() || !url.startsWith(ALLOWED_RELEASE_URL_PREFIX)) {
                            result.error("UNTRUSTED_URL", "URL is not an allowed GitHub release URL", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message ?: "Could not open browser", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

