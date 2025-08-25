package com.example.sip_phone

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import okhttp3.*
import okio.ByteString
import android.util.Log

class WebSocketService : Service() {
    
    companion object {
        const val ACTION_CONNECT = "ACTION_CONNECT"
        const val ACTION_CONNECT_WITH_PARAMS = "ACTION_CONNECT_WITH_PARAMS"
        const val ACTION_CONNECT_WITH_CONFIG = "ACTION_CONNECT_WITH_CONFIG"
        const val ACTION_DISCONNECT = "ACTION_DISCONNECT"
        const val ACTION_SEND_MESSAGE = "ACTION_SEND_MESSAGE"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "WebSocketServiceChannel"
        private const val TAG = "WebSocketService"
    }
    
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient()
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundService()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val url = intent.getStringExtra("url")
                url?.let { connectWebSocket(it) }
            }
            ACTION_CONNECT_WITH_CONFIG -> {
                val host = intent.getStringExtra("host")
                val port = intent.getIntExtra("port", 0)
                val path = intent.getStringExtra("path") ?: "/ws"
                val useSSL = intent.getBooleanExtra("useSSL", true)
                val queryParams = intent.getSerializableExtra("queryParams") as? HashMap<String, String>
                val headers = intent.getSerializableExtra("headers") as? HashMap<String, String>
                
                if (host != null && port > 0) {
                    connectWebSocketWithConfig(host, port, path, useSSL, queryParams, headers)
                }
            }
            ACTION_CONNECT_WITH_PARAMS -> {
                val host = intent.getStringExtra("host")
                val port = intent.getIntExtra("port", 0)
                val apiKey = intent.getStringExtra("apiKey")
                val empId = intent.getStringExtra("empId")
                val empName = intent.getStringExtra("empName")
                val depId = intent.getStringExtra("depId")
                val accId = intent.getStringExtra("accId")
                val additionalParams = intent.getSerializableExtra("additionalParams") as? HashMap<String, String>
                
                if (host != null && port > 0 && apiKey != null && empId != null && 
                    empName != null && depId != null && accId != null) {
                    connectWebSocketWithParams(host, port, apiKey, empId, empName, depId, accId, additionalParams)
                }
            }
            ACTION_DISCONNECT -> {
                disconnectWebSocket()
            }
            ACTION_SEND_MESSAGE -> {
                val message = intent.getStringExtra("message")
                message?.let { sendMessage(it) }
            }
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "WebSocket Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
    
    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("WebSocket Service")
            .setContentText("Maintaining WebSocket connection")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
            
        startForeground(NOTIFICATION_ID, notification)
    }
    
    private fun connectWebSocketWithConfig(
        host: String,
        port: Int,
        path: String,
        useSSL: Boolean,
        queryParams: HashMap<String, String>?,
        headers: HashMap<String, String>?
    ) {
        // Build URL with configuration
        val urlBuilder = StringBuilder()
        val protocol = if (useSSL) "wss://" else "ws://"
        urlBuilder.append(protocol).append(host)
        
        // Add port if not default
        if (port != 80 && port != 443) {
            urlBuilder.append(":").append(port)
        }
        
        // Add path
        urlBuilder.append(path)
        
        // Add query parameters
        queryParams?.let { params ->
            if (params.isNotEmpty()) {
                urlBuilder.append("?")
                params.entries.joinToString("&") { (key, value) ->
                    "$key=$value"
                }.let { urlBuilder.append(it) }
            }
        }
        
        val url = urlBuilder.toString()
        Log.d(TAG, "Connecting to WebSocket with config: $url")
        connectWebSocket(url, headers)
    }
    
    private fun connectWebSocketWithParams(
        host: String,
        port: Int,
        apiKey: String,
        empId: String,
        empName: String,
        depId: String,
        accId: String,
        additionalParams: HashMap<String, String>?
    ) {
        // Build URL with parameters
        val urlBuilder = StringBuilder()
        val protocol = if (port == 443 || port == 8443 || port == 8089) "wss://" else "ws://"
        urlBuilder.append(protocol).append(host)
        if (port != 80 && port != 443) {
            urlBuilder.append(":").append(port)
        }
        urlBuilder.append("/ws")
        urlBuilder.append("?api_key=").append(apiKey)
        urlBuilder.append("&emp_id=").append(empId)
        urlBuilder.append("&emp_name=").append(empName)
        urlBuilder.append("&dep_id=").append(depId)
        urlBuilder.append("&acc_id=").append(accId)
        
        // Add additional parameters if provided
        additionalParams?.forEach { (key, value) ->
            urlBuilder.append("&").append(key).append("=").append(value)
        }
        
        val url = urlBuilder.toString()
        Log.d(TAG, "Connecting to WebSocket: $url")
        connectWebSocket(url)
    }
    
    private fun connectWebSocket(url: String) {
        connectWebSocket(url, null)
    }
    
    private fun connectWebSocket(url: String, headers: HashMap<String, String>?) {
        disconnectWebSocket() // Disconnect any existing connection
        
        val requestBuilder = Request.Builder().url(url)
        
        // Add custom headers if provided
        headers?.forEach { (key, value) ->
            Log.d(TAG, "Adding header: $key = $value")
            requestBuilder.addHeader(key, value)
        }
        
        if (headers?.isNotEmpty() == true) {
            Log.d(TAG, "Total headers added: ${headers.size}")
        }
        
        val request = requestBuilder.build()
        
        val webSocketListener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connection opened to: $url")
                broadcastConnectionStatus(true)
            }
            
            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "Received message: $text")
                broadcastMessage(text)
            }
            
            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                Log.d(TAG, "Received bytes: ${bytes.hex()}")
                broadcastMessage(bytes.hex())
            }
            
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closing: $code $reason")
                webSocket.close(1000, null)
                broadcastConnectionStatus(false)
            }
            
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket error connecting to $url: ${t.message}")
                broadcastConnectionStatus(false)
                
                // Attempt to reconnect after a delay
                android.os.Handler(mainLooper).postDelayed({
                    connectWebSocket(url)
                }, 5000)
            }
        }
        
        webSocket = client.newWebSocket(request, webSocketListener)
    }
    
    private fun disconnectWebSocket() {
        webSocket?.close(1000, "Disconnecting")
        webSocket = null
        broadcastConnectionStatus(false)
    }
    
    private fun sendMessage(message: String) {
        webSocket?.send(message) ?: Log.w(TAG, "WebSocket not connected, cannot send message")
    }
    
    private fun broadcastMessage(message: String) {
        val intent = Intent("com.example.sip_phone.WEBSOCKET_MESSAGE").apply {
            putExtra("message", message)
        }
        sendBroadcast(intent)
    }
    
    private fun broadcastConnectionStatus(isConnected: Boolean) {
        val intent = Intent("com.example.sip_phone.WEBSOCKET_STATUS").apply {
            putExtra("isConnected", isConnected)
        }
        sendBroadcast(intent)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        disconnectWebSocket()
        client.dispatcher.executorService.shutdown()
    }
}