package com.babeel14.inkvault_reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val prefs by lazy { getSharedPreferences("baker_obsidian", MODE_PRIVATE) }
    private var pending: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "baker_reader/obsidian").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "settings" -> result.success(mapOf("uri" to prefs.getString("uri", null), "folder" to prefs.getString("folder", "Baker Reader"), "vault" to prefs.getString("vault", "")))
                    "chooseFolder" -> {
                        check(pending == null) { "Ya hay un selector abierto" }
                        pending = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION), 410)
                    }
                    "configure" -> {
                        val folder = call.argument<String>("folder") ?: ""
                        segments(folder)
                        prefs.edit().putString("folder", folder).putString("vault", call.argument<String>("vault") ?: "").apply()
                        result.success(null)
                    }
                    "unlink" -> {
                        prefs.getString("uri", null)?.let { uri ->
                            try { contentResolver.releasePersistableUriPermission(Uri.parse(uri), Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION) } catch (_: Exception) {}
                        }
                        prefs.edit().remove("uri").apply(); result.success(null)
                    }
                    "open" -> {
                        val uri = Uri.Builder().scheme("obsidian").authority("open").appendQueryParameter("vault", prefs.getString("vault", "")).build()
                        startActivity(Intent(Intent.ACTION_VIEW, uri)); result.success(null)
                    }
                    "export" -> {
                        val files = call.argument<List<Map<String, Any>>>("files") ?: emptyList()
                        Thread {
                            try {
                                val uri = Uri.parse(prefs.getString("uri", null) ?: error("Vincula Obsidian en Ajustes"))
                                var root = DocumentFile.fromTreeUri(this, uri) ?: error("Carpeta no disponible")
                                check(root.canWrite()) { "Vuelve a autorizar la carpeta en Ajustes" }
                                for (part in segments(prefs.getString("folder", "") ?: "")) root = directory(root, part)
                                for (file in files) {
                                    val parts = segments(file["path"] as String)
                                    check(parts.isNotEmpty())
                                    var parent = root
                                    for (part in parts.dropLast(1)) parent = directory(parent, part)
                                    val name = parts.last()
                                    val target = parent.findFile(name) ?: parent.createFile(file["mime"] as String, name) ?: error("No se pudo crear $name")
                                    val bytes = when (val data = file["bytes"]) {
                                        is ByteArray -> data
                                        is List<*> -> data.map { (it as Number).toByte() }.toByteArray()
                                        else -> error("Imagen no válida")
                                    }
                                    (contentResolver.openOutputStream(target.uri, "wt") ?: error("Sin acceso a $name")).use { it.write(bytes) }
                                }
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) { runOnUiThread { result.error("export", e.message, null) } }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { pending = null; result.error("obsidian", e.message, null) }
        }
    }
    private fun segments(path: String): List<String> {
        require(!path.startsWith("/") && !path.contains("\\") && !path.contains(":")) { "Usa una subcarpeta relativa" }
        val parts = path.split('/').filter { it.isNotBlank() }
        require(parts.none { it == "." || it == ".." }) { "Subcarpeta no válida" }
        return parts
    }
    private fun directory(parent: DocumentFile, name: String): DocumentFile {
        val child = parent.findFile(name) ?: parent.createDirectory(name) ?: error("No se pudo crear la carpeta")
        check(child.isDirectory) { "Ya existe un archivo con el nombre $name" }
        return child
    }
    @Deprecated("Activity result used for Flutter bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 410) return
        val callback = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { callback.success(null); return }
        try {
            val uri = data.data!!
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags)
            prefs.edit().putString("uri", uri.toString()).apply()
            callback.success(null)
        } catch (e: Exception) { callback.error("folder", e.message, null) }
    }
}
