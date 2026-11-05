package com.example.dodroidai.dodroidai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SpeechPlugin(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        AsrPlugin(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
