package com.example.sip_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private lateinit var methodHandler: WebSocketMethodHandler
    private lateinit var webSocketReceiver: BroadcastReceiver
    private lateinit var methodChannel: MethodChannel
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup method channel for WebSocket
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "websocket_service")
        methodHandler = WebSocketMethodHandler(this)
        
        methodChannel.setMethodCallHandler { call, result ->
            methodHandler.handleMethodCall(call, result)
        }
        
        // Setup broadcast receiver for WebSocket events
        webSocketReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    "com.example.sip_phone.WEBSOCKET_MESSAGE" -> {
                        val message = intent.getStringExtra("message")
                        message?.let {
                            methodChannel.invokeMethod("onMessageReceived", mapOf("message" to it))
                        }
                    }
                    "com.example.sip_phone.WEBSOCKET_STATUS" -> {
                        val isConnected = intent.getBooleanExtra("isConnected", false)
                        methodChannel.invokeMethod("onConnectionStatusChanged", mapOf("isConnected" to isConnected))
                    }
                }
            }
        }
        
        // Register broadcast receiver with RECEIVER_NOT_EXPORTED for security
        val filter = IntentFilter().apply {
            addAction("com.example.sip_phone.WEBSOCKET_MESSAGE")
            addAction("com.example.sip_phone.WEBSOCKET_STATUS")
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(webSocketReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(webSocketReceiver, filter)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        methodHandler.cleanup()
        unregisterReceiver(webSocketReceiver)
    }
}
