package com.rpgmaster.recovery.rpg_master_set

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

@Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
class MainActivity : FlutterActivity() {
    private data class PendingExport(
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    private var pendingExport: PendingExport? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rpg_master_set/chronicle_export",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("name")
            val mimeType = call.argument<String>("mimeType")
            if (bytes == null || name == null || mimeType == null) {
                result.error("invalid_export", "Arquivo inválido.", null)
                return@setMethodCallHandler
            }
            if (pendingExport != null) {
                result.error("export_in_progress", "Já há um arquivo para salvar.", null)
                return@setMethodCallHandler
            }

            val picker = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, name)
            }
            pendingExport = PendingExport(bytes, result)
            try {
                startActivityForResult(picker, CREATE_EXPORT_DOCUMENT)
            } catch (error: Exception) {
                pendingExport = null
                result.error("picker_unavailable", "Não foi possível abrir o seletor de arquivos.", null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CREATE_EXPORT_DOCUMENT) return
        val export = pendingExport ?: return
        pendingExport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            export.result.success(false)
            return
        }

        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("Missing document output stream")
                stream.use { it.write(export.bytes) }
                runOnUiThread { export.result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    export.result.error("write_failed", "Não foi possível salvar o arquivo.", null)
                }
            }
        }.start()
    }

    companion object {
        private const val CREATE_EXPORT_DOCUMENT = 9207
    }
}
