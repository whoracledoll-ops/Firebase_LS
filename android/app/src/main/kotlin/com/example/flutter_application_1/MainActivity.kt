package com.example.flutter_application_1

// 💡 注意：1行目の package 行は絶対に消さず、元からあるものをそのまま使ってください。

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.posthive.app/speech"
    private var speechRecognizer: SpeechRecognizer? = null
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    val localeId = call.argument<String>("localeId") ?: "ja_JP"
                    startSpeechRecognition(localeId)
                    result.success(true)
                }
                "stopListening" -> {
                    speechRecognizer?.stopListening()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

private fun startSpeechRecognition(localeId: String) {
        // 💡 修正1：以前のエンジンを完全に破壊してリセットする
        speechRecognizer?.destroy()
        
        // 💡 修正2：毎回必ず「新品のエンジン」を作り直す（if文での使い回しを廃止）
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                channel.invokeMethod("onStatus", "listening")
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            
            override fun onEndOfSpeech() {}
            
            override fun onError(error: Int) {
                channel.invokeMethod("onError", error)
                channel.invokeMethod("onStatus", "notListening")
            }
            
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    val data = mapOf("text" to matches[0], "isFinal" to true)
                    channel.invokeMethod("onResult", data)
                }
                channel.invokeMethod("onStatus", "notListening")
            }
            
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    val data = mapOf("text" to matches[0], "isFinal" to false)
                    channel.invokeMethod("onResult", data)
                }
            }
            
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            
            // 💡 修正3：Android OSが確実に認識できるよう、ja_JP を ja-JP（ハイフン）に自動変換して渡す
            val safeLocale = localeId.replace("_", "-")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, safeLocale)
            
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 5000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 5000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 5000L)
        }
        speechRecognizer?.startListening(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
    }
}