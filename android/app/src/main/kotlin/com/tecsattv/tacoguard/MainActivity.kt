package com.tecsattv.tacoguard

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Bip do aviso de velocidade.
// 1.8.0: som próprio (res/raw/bip.wav), tocado como alarme (ouve-se mesmo
// com o volume de mídia baixo). Se o som não carregar, usa o tom do sistema.
class MainActivity : FlutterActivity() {
    private var pool: SoundPool? = null
    private var bipId = 0
    private var loaded = false
    private var tone: ToneGenerator? = null
    private var tacho: TachoBt? = null // 1.11.0: ligação ao tacógrafo

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tacho = TachoBt(this, flutterEngine.dartExecutor.binaryMessenger)
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            pool = SoundPool.Builder().setMaxStreams(2).setAudioAttributes(attrs).build()
            pool?.setOnLoadCompleteListener { _, _, status -> loaded = status == 0 }
            bipId = pool?.load(this, R.raw.bip, 1) ?: 0
        } catch (e: Exception) {
            pool = null
        }
        // 1.10.3: pastas do app (no lugar do plugin path_provider, que
        // passou a falhar). "docs" = a mesma pasta de antes (app_flutter).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tacoguard/dirs")
            .setMethodCallHandler { call, result ->
                if (call.method == "dirs") {
                    try {
                        result.success(
                            mapOf(
                                "docs" to getDir("flutter", MODE_PRIVATE).path,
                                "temp" to cacheDir.path
                            )
                        )
                    } catch (e: Exception) {
                        result.error("dirs", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tacoguard/beep")
            .setMethodCallHandler { call, result ->
                if (call.method == "beep") {
                    try {
                        // 1.9.6: volume escolhido nos Ajustes (0,1 a 1,0).
                        val vol = ((call.argument<Double>("vol") ?: 1.0).toFloat())
                            .coerceIn(0.05f, 1f)
                        val p = pool
                        if (p != null && loaded && bipId != 0) {
                            p.play(bipId, vol, vol, 1, 0, 1f)
                        } else {
                            if (tone == null) {
                                tone = ToneGenerator(AudioManager.STREAM_ALARM, (vol * 100).toInt())
                            }
                            tone?.startTone(ToneGenerator.TONE_PROP_BEEP2, 400)
                        }
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
        tacho?.close()
        pool?.release()
        pool = null
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
