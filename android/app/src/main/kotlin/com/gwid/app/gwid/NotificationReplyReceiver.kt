package com.gwid.app.gwid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import io.flutter.view.FlutterCallbackInformation

class NotificationReplyReceiver : BroadcastReceiver() {
    companion object {
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            android.util.Log.d("NotificationReplyReceiver", "MethodChannel установлен")
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("NotificationReplyReceiver", "onReceive called, action: ${intent.action}")
        
        if (intent.action == "com.gwid.app.REPLY_ACTION") {
            val remoteInput = RemoteInput.getResultsFromIntent(intent)
            if (remoteInput != null) {
                val replyText = remoteInput.getCharSequence("key_text_reply")?.toString()
                val chatId = intent.getLongExtra("chat_id", 0L)
                
                android.util.Log.d("NotificationReplyReceiver", "Reply text: $replyText, chatId: $chatId")
                
                if (replyText != null && replyText.isNotEmpty() && chatId != 0L) {
                    // Пытаемся отправить через существующий MethodChannel
                    try {
                        methodChannel?.invokeMethod("sendReplyFromNotification", mapOf(
                            "chatId" to chatId.toInt(),
                            "text" to replyText
                        ))
                        android.util.Log.d("NotificationReplyReceiver", "Отправлен reply через MethodChannel")
                        
                        // Отменяем уведомление после отправки
                        val notificationHelper = NotificationHelper(context)
                        notificationHelper.cancelNotification(chatId)
                    } catch (e: Exception) {
                        android.util.Log.e("NotificationReplyReceiver", "Ошибка отправки через MethodChannel: ${e.message}")
                        // Сохраняем для обработки при следующем запуске
                        savePendingReply(context, chatId, replyText)
                    }
                }
            }
        }
    }
    
    private fun savePendingReply(context: Context, chatId: Long, text: String) {
        try {
            val prefs = context.getSharedPreferences("flutter_notification_replies", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            editor.putLong("pending_reply_chat_id", chatId)
            editor.putString("pending_reply_text", text)
            editor.putLong("pending_reply_timestamp", System.currentTimeMillis())
            editor.apply()
            android.util.Log.d("NotificationReplyReceiver", "Сохранён pending reply в SharedPreferences")
        } catch (e: Exception) {
            android.util.Log.e("NotificationReplyReceiver", "Ошибка сохранения pending reply: ${e.message}")
        }
    }
}
