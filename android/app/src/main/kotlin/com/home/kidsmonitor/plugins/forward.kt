package com.example.telegramforwarder

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.AsyncTask
import android.provider.MediaStore
import android.util.Log
import androidx.core.net.toUri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class TelegramForwarderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "telegram_forwarder")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "forwardToTelegram" -> {
                val filePath = call.argument<String>("filePath")
                val botToken = call.argument<String>("botToken")
                val chatId = call.argument<String>("chatId")
                
                if (filePath != null && botToken != null && chatId != null) {
                    ForwardTask(context, result).execute(filePath, botToken, chatId)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing required parameters", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private class ForwardTask(
        private val context: Context,
        private val result: Result
    ) : AsyncTask<String, Void, String>() {
        
        override fun doInBackground(vararg params: String): String {
            val filePath = params[0]
            val botToken = params[1]
            val chatId = params[2]
            
            return try {
                val file = getFileFromUri(context, filePath.toUri())
                if (file != null && file.exists()) {
                    sendToTelegram(file, botToken, chatId)
                    "SUCCESS"
                } else {
                    "FILE_NOT_FOUND"
                }
            } catch (e: Exception) {
                Log.e("TelegramForwarder", "Error: ${e.message}")
                "ERROR: ${e.message}"
            }
        }

        override fun onPostExecute(response: String) {
            when {
                response == "SUCCESS" -> result.success(true)
                response == "FILE_NOT_FOUND" -> result.error("FILE_NOT_FOUND", "File not found", null)
                else -> result.error("UPLOAD_FAILED", response, null)
            }
        }

        private fun getFileFromUri(context: Context, uri: Uri): File? {
            return try {
                val contentResolver: ContentResolver = context.contentResolver
                val inputStream: InputStream? = contentResolver.openInputStream(uri)
                val fileName = getFileName(contentResolver, uri)
                val file = createTempFile(context, fileName)
                
                inputStream?.use { input ->
                    FileOutputStream(file).use { output ->
                        input.copyTo(output)
                    }
                }
                file
            } catch (e: Exception) {
                Log.e("TelegramForwarder", "Error creating file: ${e.message}")
                null
            }
        }

        private fun getFileName(contentResolver: ContentResolver, uri: Uri): String {
            var name = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
            
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                    if (index >= 0) name = cursor.getString(index)
                }
            }
            return name
        }

        private fun createTempFile(context: Context, fileName: String): File {
            val storageDir = context.cacheDir
            return File.createTempFile(
                "temp_${System.currentTimeMillis()}_",
                ".${fileName.substringAfterLast('.', "")}",
                storageDir
            )
        }

        private fun sendToTelegram(file: File, botToken: String, chatId: String): Boolean {
            val client = OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .build()

            val requestBody = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart(
                    "document",
                    file.name,
                    file.asRequestBody("application/octet-stream".toMediaTypeOrNull())
                )
                .addFormDataPart("chat_id", chatId)
                .build()

            val request = Request.Builder()
                .url("https://api.telegram.org/bot$botToken/sendDocument")
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""
            
            if (!response.isSuccessful) {
                Log.e("TelegramForwarder", "Upload failed: $responseBody")
                throw Exception("Telegram API error: ${response.code}")
            }
            
            file.delete()
            return true
        }
    }
}