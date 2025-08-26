# VoIP Background Call Architecture (Like WhatsApp)

## Current Problem
- When app is closed → SIP unregistered → "Extension is off"
- FCM arrives before SIP connection → Timing mismatch
- Need to work like WhatsApp/Telegram even when app is closed

## Complete Solution Architecture

### 1. SERVER-SIDE CHANGES (Critical - for VoIP Engineer)

#### A. User Presence Management
```
- Track user online/offline status
- When app closes → Mark user as "PUSH_AVAILABLE" (not offline)
- When someone calls offline user → Queue the call + Send FCM
- Don't immediately reject calls to closed apps
```

#### B. Call Queuing System
```
Server Call Flow:
1. Incoming call to 564612@sip.ibos.io
2. Check if user is registered:
   - If ONLINE → Route call immediately
   - If OFFLINE → Queue call + Send FCM push
3. Wait for app to register (after FCM wakes it up)
4. Once app registers → Route the queued call
5. Timeout after 30 seconds if app doesn't respond
```

#### C. FCM Integration on Server
```
When user goes offline:
1. Store FCM token for user 564612
2. Store device info and push preferences
3. When call arrives for offline user:
   - Send FCM with call metadata
   - Queue the actual SIP call
   - Wait for client to come online
```

### 2. CLIENT-SIDE IMPLEMENTATION (Current App)

#### A. FCM Message Format (Server should send)
```json
{
  "data": {
    "type": "incoming_call",
    "caller_id": "01234567890", 
    "caller_name": "John Doe",
    "call_uuid": "unique-call-id",
    "server_call_id": "server-internal-id"
  }
}
```

#### B. App Background Flow
```
1. FCM arrives → App wakes up
2. CallKit shows native call UI immediately
3. App connects to SIP server
4. App sends "I'm ready for call X" to server  
5. Server routes the queued call
6. Normal SIP call flow begins
```

### 3. IMPLEMENTATION STEPS

#### Step 1: Server Changes (VoIP Engineer)
```bash
# Asterisk configuration needed:

# 1. Add FCM push functionality
# 2. Modify dial plan to handle offline users
# 3. Add call queuing mechanism
# 4. Add presence management

[extensions.conf]
exten => 564612,1,GotoIf($[${DEVICE_STATE(PJSIP/564612)}=UNAVAILABLE]?push:call)
exten => 564612,n(call),Dial(PJSIP/564612,30)
exten => 564612,n(push),System(/path/to/send_fcm_push.py ${CALLERID(num)} ${CALLERID(name)} 564612)
exten => 564612,n,Wait(30)
exten => 564612,n,GotoIf($[${DEVICE_STATE(PJSIP/564612)}=NOT_INUSE]?call:voicemail)
```

#### Step 2: Enhanced CallKit (Current App)
```dart
// Real CallKit implementation needed
// Current placeholder won't work for production

dependencies:
  flutter_callkit_incoming: ^2.0.0  # Real CallKit
  # OR
  connectycube_flutter_call_kit: ^2.8.0
```

#### Step 3: Background App State Management
```dart
// Add to app lifecycle management
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background
        SipService().notifyServerAppClosing();
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground
        SipService().reconnectAfterBackground();
        break;
    }
  }
}
```

### 4. HOW WHATSAPP/TELEGRAM DO IT

#### WhatsApp Architecture:
```
1. WhatsApp servers track user online status
2. When user offline → Server keeps "push availability" 
3. Incoming call → Server sends FCM → App wakes up
4. App shows CallKit UI → Connects to server → Receives real call
5. Works even when app completely closed
```

#### Telegram Architecture:
```
1. Similar to WhatsApp
2. Uses VOIP push notifications (APNs on iOS)
3. Server-side call queuing
4. Client reconnection after push
```

### 5. ANDROID PERMISSIONS NEEDED

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.BIND_TELECOM_CONNECTION_SERVICE" />
```

### 6. PRODUCTION TIMELINE

#### Phase 1 (Current): Basic FCM + Manual Testing
- ✅ FCM notifications working
- ✅ App opens when notification tapped
- ⏳ Need server-side call queuing

#### Phase 2: Server Integration
- VoIP engineer implements call queuing
- Server FCM integration
- Test with real background scenarios

#### Phase 3: Native CallKit
- Implement real CallKit (not placeholder)
- Handle accept/decline from lock screen
- Full background call support

#### Phase 4: Production Polish
- Handle edge cases (low battery, doze mode)
- Call quality optimization
- Multi-device support

### 7. IMMEDIATE ACTIONS NEEDED

#### For VoIP Engineer:
1. **Implement call queuing on Asterisk**
2. **Add FCM push notification sending**  
3. **Modify dial plan for offline users**
4. **Add "app ready" callback handling**

#### For App:
1. **Test current FCM flow with server engineer**
2. **Implement real CallKit (not placeholder)**
3. **Add app lifecycle management**
4. **Handle background reconnection**

### 8. TESTING CHECKLIST

#### Background Call Test:
```
1. ✅ App running → Receive calls (works)
2. ⏳ App in background → Receive calls (needs server fix)
3. ⏳ App completely closed → Receive calls (needs CallKit)
4. ⏳ FCM → App opens → Real call arrives (needs timing fix)
```

This architecture will make your app work exactly like WhatsApp for VoIP calls.