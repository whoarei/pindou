package com.pindou.studio

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val FILES_CHANNEL = "com.pindou.studio/files"
        private const val PICK_IMAGE_REQUEST = 9020
        private const val CREATE_JPEG_REQUEST = 9021
    }

    private var pendingBytes: ByteArray? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> {
                        if (pendingPickResult != null) {
                            result.error("PICK_BUSY", "另一个图片选择操作正在进行。", null)
                            return@setMethodCallHandler
                        }
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png"))
                        }
                        startActivityForResult(intent, PICK_IMAGE_REQUEST)
                    }
                    "saveJpeg" -> {
                        if (pendingExportResult != null) {
                            result.error("EXPORT_BUSY", "另一个导出操作正在进行。", null)
                            return@setMethodCallHandler
                        }
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "pattern.jpg"
                        if (bytes == null) {
                            result.error("INVALID_DATA", "没有可导出的图片数据。", null)
                            return@setMethodCallHandler
                        }
                        pendingBytes = bytes
                        pendingExportResult = result
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/jpeg"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        startActivityForResult(intent, CREATE_JPEG_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            val result = pendingPickResult
            pendingPickResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result?.success(null)
                return
            }
            try {
                val uri = data.data!!
                val bytes = contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "无法读取所选文件。" }
                    input.readBytes()
                }
                var name = "image.jpg"
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) name = cursor.getString(index)
                    }
                }
                result?.success(mapOf("bytes" to bytes, "name" to name))
            } catch (error: Exception) {
                result?.error("PICK_FAILED", error.message, null)
            }
            return
        }
        if (requestCode != CREATE_JPEG_REQUEST) return

        val result = pendingExportResult
        val bytes = pendingBytes
        pendingExportResult = null
        pendingBytes = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }
        if (bytes == null) {
            result?.error("EXPORT_FAILED", "导出数据已丢失。", null)
            return
        }

        try {
            val uri = data.data!!
            contentResolver.openOutputStream(uri, "w").use { output ->
                requireNotNull(output) { "无法打开目标文件。" }
                output.write(bytes)
            }
            result?.success(uri.toString())
        } catch (error: Exception) {
            result?.error("EXPORT_FAILED", error.message, null)
        }
    }
}
