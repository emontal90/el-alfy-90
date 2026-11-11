package com.example.furniture_erp

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val UPDATER_CHANNEL = "com.example.furniture_erp/app_updater"
        private const val BACKUP_CHANNEL = "com.example.furniture_erp/backup_transfer"
        private const val ALLOWED_RELEASE_URL_PREFIX = "https://github.com/emontal90/el-alfy-90/releases"
        private const val PICK_BACKUP_REQUEST_CODE = 4091
        private const val CREATE_BACKUP_DOC_REQUEST_CODE = 4092
        private const val MAX_EXPORTED_BACKUPS = 5
    }

    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingExportSourcePath: String? = null

    private fun isInsideAppFiles(file: File): Boolean {
        val canonicalPath = file.canonicalPath
        val allowedRoots = listOfNotNull(
            filesDir.parentFile?.canonicalPath,
            filesDir.canonicalPath,
            cacheDir.canonicalPath
        )
        return allowedRoots.any { root ->
            canonicalPath.startsWith(root + File.separator)
        }
    }

    private fun pruneOldDownloadsBackups() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DATE_MODIFIED
        )
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
        val selectionArgs = arrayOf("%ElAlfyBackups%")
        val sortOrder = "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"

        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            var index = 0
            while (cursor.moveToNext()) {
                if (index >= MAX_EXPORTED_BACKUPS) {
                    val id = cursor.getLong(idCol)
                    val itemUri = ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        id
                    )
                    try {
                        contentResolver.delete(itemUri, null, null)
                    } catch (_: Exception) {
                    }
                }
                index++
            }
        }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKUP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exportBackupToDownloads" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        if (path.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing backup path or filename", null)
                            return@setMethodCallHandler
                        }
                        val sourceFile = File(path)
                        if (!isInsideAppFiles(sourceFile) || !sourceFile.exists() || !sourceFile.isFile) {
                            result.error("INVALID_FILE", "ملف النسخة الاحتياطية غير موجود", null)
                            return@setMethodCallHandler
                        }
                        val safeName = File(fileName).name

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            try {
                                val values = ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
                                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                                    put(
                                        MediaStore.MediaColumns.RELATIVE_PATH,
                                        "${Environment.DIRECTORY_DOWNLOADS}/ElAlfyBackups"
                                    )
                                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                                }
                                val uri = contentResolver.insert(
                                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                    values
                                ) ?: throw IllegalStateException("فشل إنشاء الملف في مجلد التنزيلات")

                                contentResolver.openOutputStream(uri)?.use { out ->
                                    FileInputStream(sourceFile).use { input ->
                                        input.copyTo(out)
                                    }
                                } ?: throw IllegalStateException("تعذر فتح مجلد التنزيلات للكتابة")

                                values.clear()
                                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                contentResolver.update(uri, values, null, null)
                                pruneOldDownloadsBackups()

                                result.success("Download/ElAlfyBackups/$safeName")
                            } catch (e: Exception) {
                                result.error("EXPORT_FAILED", e.message ?: "فشل تصدير النسخة", null)
                            }
                        } else {
                            if (pendingBackupResult != null) {
                                result.error("BUSY", "يوجد عملية تصدير أو استيراد قيد التنفيذ", null)
                                return@setMethodCallHandler
                            }
                            pendingBackupResult = result
                            pendingExportSourcePath = sourceFile.absolutePath
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, safeName)
                            }
                            startActivityForResult(intent, CREATE_BACKUP_DOC_REQUEST_CODE)
                        }
                    }
                    "shareBackupFile" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        if (path.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing backup path or filename", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val sourceFile = File(path)
                            if (!isInsideAppFiles(sourceFile) || !sourceFile.exists() || !sourceFile.isFile) {
                                result.error("INVALID_FILE", "ملف النسخة الاحتياطية غير موجود", null)
                                return@setMethodCallHandler
                            }
                            val shareDir = File(cacheDir, "shared_backups")
                            if (!shareDir.exists()) shareDir.mkdirs()
                            shareDir.listFiles()?.forEach { old ->
                                if (old.isFile) old.delete()
                            }
                            val shareFile = File(shareDir, File(fileName).name)
                            sourceFile.copyTo(shareFile, overwrite = true)

                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                shareFile
                            )
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/octet-stream"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_SUBJECT, "نسخة احتياطية - نظام الألفي")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(sendIntent, "حفظ أو مشاركة النسخة الاحتياطية"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message ?: "فشل مشاركة النسخة", null)
                        }
                    }
                    "pickBackupFile" -> {
                        if (pendingBackupResult != null) {
                            result.error("BUSY", "يوجد عملية قيد التنفيذ", null)
                            return@setMethodCallHandler
                        }
                        pendingBackupResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, PICK_BACKUP_REQUEST_CODE)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == PICK_BACKUP_REQUEST_CODE) {
            val callback = pendingBackupResult ?: return
            pendingBackupResult = null

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }

            try {
                val uri = data.data!!
                val importDir = File(cacheDir, "shared_backups")
                if (!importDir.exists()) importDir.mkdirs()
                val tempFile = File(importDir, "imported_candidate.db")
                if (tempFile.exists()) tempFile.delete()

                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(tempFile).use { output ->
                        input.copyTo(output)
                    }
                } ?: run {
                    callback.error("READ_FAILED", "تعذر قراءة الملف المختار", null)
                    return
                }

                // التحقق من ترويسة ملف SQLite الرسمية: "SQLite format 3\0"
                val expectedHeader = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)
                val header = ByteArray(16)
                val bytesRead = FileInputStream(tempFile).use { it.read(header) }
                if (bytesRead < 16 || !header.contentEquals(expectedHeader) || tempFile.length() < 1024) {
                    tempFile.delete()
                    callback.error("INVALID_SQLITE", "الملف المختار ليس نسخة احتياطية صالحة (.db)", null)
                    return
                }

                callback.success(tempFile.absolutePath)
            } catch (e: Exception) {
                callback.error("IMPORT_FAILED", e.message ?: "فشل قراءة النسخة الاحتياطية", null)
            }
            return
        }

        if (requestCode == CREATE_BACKUP_DOC_REQUEST_CODE) {
            val callback = pendingBackupResult ?: return
            val sourcePath = pendingExportSourcePath
            pendingBackupResult = null
            pendingExportSourcePath = null

            if (resultCode != Activity.RESULT_OK || data?.data == null || sourcePath == null) {
                callback.success(null)
                return
            }

            try {
                val uri = data.data!!
                val sourceFile = File(sourcePath)
                contentResolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(out)
                    }
                } ?: run {
                    callback.error("EXPORT_FAILED", "تعذر الكتابة إلى المسار المختار", null)
                    return
                }
                callback.success(sourceFile.name)
            } catch (e: Exception) {
                callback.error("EXPORT_FAILED", e.message ?: "فشل حفظ النسخة الاحتياطية", null)
            }
        }
    }
}

