package com.example.sip_phone

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WebSocketMethodHandler(private val context: Context) {
    
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connectWebSocketWithConfig" -> {
                val host = call.argument<String>("host")
                val port = call.argument<Int>("port")
                val path = call.argument<String>("path") ?: "/ws"
                val useSSL = call.argument<Boolean>("useSSL") ?: true
                val queryParams = call.argument<Map<String, String>>("queryParams") ?: emptyMap()
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                
                if (host != null && port != null) {
                    connectWithConfig(host, port, path, useSSL, queryParams, headers, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Host and port are required", null)
                }
            }
            "connectWebSocket" -> {
                val host = call.argument<String>("host")
                val port = call.argument<Int>("port")
                val apiKey = call.argument<String>("apiKey")
                val empId = call.argument<String>("empId")
                val empName = call.argument<String>("empName")
                val depId = call.argument<String>("depId")
                val accId = call.argument<String>("accId")
                val additionalParams = call.argument<Map<String, String>>("additionalParams")
                
                if (host != null && port != null && apiKey != null && empId != null && 
                    empName != null && depId != null && accId != null) {
                    connectWebSocketWithParams(host, port, apiKey, empId, empName, depId, accId, additionalParams, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Required parameters are missing", null)
                }
            }
            "connectWebSocketWithUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    connectWebSocketWithUrl(url, result)
                } else {
                    result.error("INVALID_ARGUMENT", "URL is required", null)
                }
            }
            "disconnectWebSocket" -> {
                disconnectWebSocket(result)
            }
            "sendMessage" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    sendMessage(message, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Message is required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun connectWithConfig(
        host: String,
        port: Int,
        path: String,
        useSSL: Boolean,
        queryParams: Map<String, String>,
        headers: Map<String, String>,
        result: MethodChannel.Result
    ) {
        try {
            val intent = Intent(context, WebSocketService::class.java).apply {
                action = WebSocketService.ACTION_CONNECT_WITH_CONFIG
                putExtra("host", host)
                putExtra("port", port)
                putExtra("path", path)
                putExtra("useSSL", useSSL)
                putExtra("queryParams", HashMap(queryParams))
                putExtra("headers", HashMap(headers))
            }
            context.startForegroundService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }
    
    private fun connectWebSocketWithParams(
        host: String,
        port: Int,
        apiKey: String,
        empId: String,
        empName: String,
        depId: String,
        accId: String,
        additionalParams: Map<String, String>?,
        result: MethodChannel.Result
    ) {
        try {
            val intent = Intent(context, WebSocketService::class.java).apply {
                action = WebSocketService.ACTION_CONNECT_WITH_PARAMS
                putExtra("host", host)
                putExtra("port", port)
                putExtra("apiKey", apiKey)
                putExtra("empId", empId)
                putExtra("empName", empName)
                putExtra("depId", depId)
                putExtra("accId", accId)
                if (additionalParams != null) {
                    putExtra("additionalParams", HashMap(additionalParams))
                }
            }
            context.startForegroundService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }
    
    private fun connectWebSocketWithUrl(url: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(context, WebSocketService::class.java).apply {
                action = WebSocketService.ACTION_CONNECT
                putExtra("url", url)
            }
            context.startForegroundService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }
    
    private fun disconnectWebSocket(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, WebSocketService::class.java).apply {
                action = WebSocketService.ACTION_DISCONNECT
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECTION_ERROR", e.message, null)
        }
    }
    
    private fun sendMessage(message: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(context, WebSocketService::class.java).apply {
                action = WebSocketService.ACTION_SEND_MESSAGE
                putExtra("message", message)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }
    
    fun cleanup() {
        // Cleanup resources if needed
    }
}