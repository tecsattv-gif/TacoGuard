package com.tecsattv.tacoguard

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 1.7.9: bip do aviso de velocidade (canal de alarme, toca mesmo com o
// volume de mídia baixo).
class MainActivity : FlutterActivity() {
    private var tone: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tacoguard/beep")
            .setMethodCallHandler { call, result ->
                if (call.method == "beep") {
                    try {
                        if (tone == null) {
                            tone = ToneGenerator(AudioManager.STREAM_ALARM, 100)
                        }
                        tone?.startTone(ToneGenerator.TONE_PROP_BEEP2, 400)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("beep", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
