package com.almoktaber

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.ClipData
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.almoktaber/whatsapp_report"
        private const val AUTHORITY = "com.almoktaber.fileprovider"
        private const val WHATSAPP = "com.whatsapp"
        private const val WHATSAPP_BUSINESS = "com.whatsapp.w4b"
        private const val SHARED_DIRECTORY = "shared_reports"
        private const val JID_SUFFIX = "@s.whatsapp.net"

        private const val STATUS_LAUNCHED = "launched"
        private const val ERROR_NOT_FOUND = "WHATSAPP_NOT_FOUND"
        private const val ERROR_FILE = "FILE_UNAVAILABLE"
        private const val ERROR_PHONE = "INVALID_PHONE"
        private const val ERROR_FAILED = "SHARE_FAILED"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "availablePackages" -> result.success(installedWhatsAppPackages())
                    "openChat" -> openChat(call, result)
                    "shareToChat" -> shareToChat(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /** يكتشف الحزم المثبتة من القائمة المصرّح بها في <queries> فقط. */
    private fun installedWhatsAppPackages(): List<String> =
        listOf(WHATSAPP, WHATSAPP_BUSINESS).filter(::isInstalled)

    private fun isInstalled(packageName: String): Boolean = try {
        packageManager.getPackageInfo(packageName, 0) != null
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun resolvePackage(requested: String?): String? {
        if (!requested.isNullOrBlank()) {
            return requested.takeIf(::isInstalled)
        }
        return listOf(WHATSAPP, WHATSAPP_BUSINESS).firstOrNull(::isInstalled)
    }

    /** يفتح محادثة الرقم بالنص عبر wa.me. لا يرفق ملفاً ولا يؤكد وصول الرسالة. */
    private fun openChat(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone")?.trim().orEmpty()
        val text = call.argument<String>("text").orEmpty()
        if (phone.isEmpty()) {
            result.error(ERROR_PHONE, "رقم ولي الأمر فارغ.", null)
            return
        }
        val packageName = resolvePackage(call.argument<String>("package"))
        if (packageName == null) {
            result.error(ERROR_NOT_FOUND, "واتساب غير مثبت على الجهاز.", null)
            return
        }

        val url = "https://wa.me/$phone?text=${Uri.encode(text)}"
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage(packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(intent)
            result.success(
                mapOf(
                    "status" to STATUS_LAUNCHED,
                    "package" to packageName,
                    "message" to "تم فتح التطبيق فقط؛ لم يُرسل أي نص."
                )
            )
        } catch (_: ActivityNotFoundException) {
            result.error(ERROR_NOT_FOUND, "تعذر فتح واتساب.", null)
        } catch (error: Exception) {
            result.error(ERROR_FAILED, error.message ?: "تعذر فتح واتساب.", null)
        }
    }

    /**
     * يحاول فتح محادثة محددة مع إرفاق التقرير والنص.
     *
     * حقل "jid" غير موثق من واتساب. نجاح startActivity يعني فقط أن التطبيق
     * فُتح، ولا يعني أن واتساب وجّه المحتوى إلى تلك المحادثة؛ لذلك تُعاد
     * حالة "launched" فقط وليس حالة "sent".
     */
    private fun shareToChat(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone")?.trim().orEmpty()
        val text = call.argument<String>("text").orEmpty()
        val filePath = call.argument<String>("filePath")?.trim().orEmpty()
        val mimeType = call.argument<String>("mimeType")?.takeIf { it.isNotBlank() } ?: "*/*"
        val expectedJid = "$phone$JID_SUFFIX"
        val jid = call.argument<String>("jid")?.takeIf { it == expectedJid }
            ?: expectedJid

        if (phone.isEmpty()) {
            result.error(ERROR_PHONE, "رقم ولي الأمر فارغ.", null)
            return
        }

        val source = File(filePath)
        if (filePath.isEmpty() || !source.exists() || source.length() == 0L) {
            result.error(ERROR_FILE, "ملف التقرير غير متاح أو فارغ.", null)
            return
        }

        //FileProvider يسمح فقط بالمجلدات المعلنة في file_paths.xml.
        val cacheRoot = cacheDir.canonicalFile
        if (!source.canonicalFile.path.startsWith(cacheRoot.path + File.separator)) {
            result.error(ERROR_FILE, "مسار التقرير خارج مجلد التخزين المؤقت المسموح.", null)
            return
        }

        val sharedDirectory = File(cacheDir, SHARED_DIRECTORY)
        if (!sharedDirectory.exists() && !sharedDirectory.mkdirs()) {
            result.error(ERROR_FILE, "تعذر إنشاء مجلد المشاركة.", null)
            return
        }
        val sharedFile = File(sharedDirectory, source.name)
        if (source.canonicalFile.path != sharedFile.canonicalFile.path) {
            source.copyTo(sharedFile, overwrite = true)
        }

        val uri = try {
            FileProvider.getUriForFile(this, AUTHORITY, sharedFile)
        } catch (error: Exception) {
            result.error(ERROR_FILE, error.message ?: "تعذر إنشاء URI للملف.", null)
            return
        }

        val packageName = resolvePackage(call.argument<String>("package"))
        if (packageName == null) {
            result.error(ERROR_NOT_FOUND, "واتساب غير مثبت على الجهاز.", null)
            return
        }

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            // حقل غير رسمي؛ قد يتجاهله واتساب ولا يمكن اكتشاف ذلك من التطبيق.
            putExtra("jid", jid)
            setPackage(packageName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            clipData = ClipData.newUri(contentResolver, "student_report", uri)
        }

        try {
            startActivity(intent)
            result.success(
                mapOf(
                    "status" to STATUS_LAUNCHED,
                    "package" to packageName,
                    "jid" to jid,
                    "message" to "تم فتح التطبيق فقط؛ تأكد من المحادثة قبل الإرسال."
                )
            )
        } catch (_: ActivityNotFoundException) {
            result.error(ERROR_NOT_FOUND, "تعذر فتح واتساب.", null)
        } catch (error: Exception) {
            result.error(ERROR_FAILED, error.message ?: "تعذر مشاركة التقرير.", null)
        }
    }
}
