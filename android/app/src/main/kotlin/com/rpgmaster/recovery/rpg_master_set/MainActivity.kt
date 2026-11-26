package com.rpgmaster.recovery.rpg_master_set

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class ChronicleFileProvider : FileProvider()

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
            if (call.method != "saveFile" && call.method != "shareFile") {
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
            if (call.method == "shareFile") {
                shareChronicle(bytes, name, mimeType, result)
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

    private fun shareChronicle(
        bytes: ByteArray,
        name: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        val expectedExtension = when (mimeType) {
            "application/pdf" -> ".pdf"
            "image/png" -> ".png"
            else -> null
        }
        if (expectedExtension == null || !name.endsWith(expectedExtension) ||
            !name.matches(Regex("[a-z0-9-]{1,70}\\.(pdf|png)"))
        ) {
            result.error("invalid_export", "Arquivo inválido.", null)
            return
        }

        Thread {
            val root = File(cacheDir, "chronicle_exports")
            val cutoff = System.currentTimeMillis() - ONE_DAY_MILLIS
            root.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.deleteRecursively() }
            val directory = File(root, UUID.randomUUID().toString())
            try {
                if (!directory.mkdirs()) throw IllegalStateException("Missing share directory")
                val file = File(directory, name)
                file.writeBytes(bytes)
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.chronicle_exports",
                    file,
                )
                val share = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    clipData = ClipData.newRawUri(name, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                runOnUiThread {
                    try {
                        startActivity(Intent.createChooser(share, null))
                        result.success(true)
                    } catch (error: Exception) {
                        directory.deleteRecursively()
                        result.error("share_unavailable", "Não foi possível abrir o compartilhamento.", null)
                    }
                }
            } catch (error: Exception) {
                directory.deleteRecursively()
                runOnUiThread {
                    result.error("share_failed", "Não foi possível preparar o arquivo para compartilhar.", null)
                }
            }
        }.start()
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
        private const val ONE_DAY_MILLIS = 24 * 60 * 60 * 1000L
    }
}
