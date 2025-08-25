package com.example.sip_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "websocket_service"
    private lateinit var webSocketMethodHandler: WebSocketMethodHandler
    private lateinit var methodChannel: MethodChannel
    
    private val messageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.sip_phone.WEBSOCKET_MESSAGE" -> {
                    val message = intent.getStringExtra("message") ?: ""
                    methodChannel.invokeMethod("onMessageReceived", mapOf("message" to message))
                }
                "com.example.sip_phone.WEBSOCKET_STATUS" -> {
                    val isConnected = intent.getBooleanExtra("isConnected", false)
                    methodChannel.invokeMethod("onConnectionStatusChanged", mapOf("isConnected" to isConnected))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        webSocketMethodHandler = WebSocketMethodHandler(this)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel.setMethodCallHandler { call, result ->
            webSocketMethodHandler.handleMethodCall(call, result)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        registerBroadcastReceivers()
        
        val serviceIntent = Intent(this, WebSocketService::class.java)
        startForegroundService(serviceIntent)
    }

    private fun registerBroadcastReceivers() {
        val filter = IntentFilter().apply {
            addAction("com.example.sip_phone.WEBSOCKET_MESSAGE")
            addAction("com.example.sip_phone.WEBSOCKET_STATUS")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(messageReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(messageReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(messageReceiver)
        webSocketMethodHandler.cleanup()
    }
}
