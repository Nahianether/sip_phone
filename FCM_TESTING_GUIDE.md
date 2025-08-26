# 🧪 FCM Testing Guide for Manual Notifications

## ✅ **Setup Complete - Ready for Testing!**

Your app now has:
- ✅ **FCM token generation** 
- ✅ **Background message handling**
- ✅ **Enhanced debugging and logging**
- ✅ **Test button in Settings screen**
- ✅ **Android permissions configured**

---

## 🚀 **How to Test FCM Notifications**

### **Step 1: Run Your App**
```bash
flutter run -d V2247
```

### **Step 2: Get Your FCM Token**
1. Open the app on your Android device
2. Go to **Settings screen**  
3. Scroll down to **"Background Calls (FCM + CallKit)"** section
4. **Copy the FCM token** (long string)
5. Click **"📱 Test FCM Notifications"** for detailed instructions

### **Step 3: Open Firebase Console**
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Select your Firebase project
3. Go to **Cloud Messaging** (in left sidebar)
4. Click **"Send your first message"**

### **Step 4: Configure Test Notification**

**📝 Notification Tab:**
- **Notification title:** `Incoming Call from John Doe`
- **Notification text:** `Tap to answer the call`

**🎯 Target Tab:**
- **App:** Select your app (`com.example.sip_phone`)
- **Token:** Paste the FCM token you copied from app

**⚙️ Additional Options Tab:**
Click **"Additional options"** then **"Advanced"**

**Custom data:** (KEY : VALUE)
```
type : incoming_call
caller_id : 01687722962  
caller_name : John Doe
call_uuid : test_call_123
```

### **Step 5: Send Test Notification**
Click **"Review"** then **"Publish"**

---

## 🧪 **Test Scenarios**

### **Scenario 1: App in Foreground**
- **Expected:** Debug logs show FCM message received
- **Look for:** `🔥 FCM Foreground message received!`
- **Result:** Call simulation logs appear

### **Scenario 2: App in Background**  
- Minimize app (don't close completely)
- Send FCM notification
- **Expected:** Notification appears in status bar
- **Action:** Tap notification to open app

### **Scenario 3: App Completely Closed**
- Close app completely (swipe away from recents)
- Send FCM notification  
- **Expected:** Notification appears, app opens when tapped
- **Look for:** Background handler logs

---

## 👀 **Debug Logs to Watch For**

When FCM works correctly, you'll see:

```
🔥 FCM Foreground message received!
🔥 Title: Incoming Call from John Doe
🔥 Body: Tap to answer the call
🔥 Data: {type: incoming_call, caller_id: 01687722962, ...}
🔥 FCM: Handling as incoming call notification
🔥 FCM: Handling incoming call from John Doe (01687722962)
🔥 FCM: Call UUID: test_call_123
CallKit: Showing incoming call from John Doe (01687722962)
🔥 FCM: *** INCOMING CALL SIMULATION ***
🔥 FCM: Caller: John Doe
🔥 FCM: Number: 01687722962
🔥 FCM: UUID: test_call_123
🔥 FCM: [Accept] [Decline] buttons would be shown
🔥 FCM: Ringtone would be playing
🔥 FCM: *** END SIMULATION ***
```

---

## 🔧 **Troubleshooting**

### **No FCM Token Showing?**
- Check if Firebase is initialized properly
- Look for Firebase initialization errors in logs
- Ensure `google-services.json` is in correct location

### **Notification Not Received?**
- Verify FCM token is copied correctly (no extra spaces)
- Check if app has notification permissions
- Try different test scenarios (foreground/background/closed)

### **No Debug Logs?**
- Make sure you're watching Flutter debug console
- Try running with: `flutter run -d V2247 --verbose`
- Check that debug prints are enabled

### **Firebase Console Errors?**
- Verify your Firebase project is set up correctly
- Ensure Android app is added to project  
- Check that `google-services.json` matches your project

---

## 📱 **Quick Testing Workflow**

1. **Run app:** `flutter run -d V2247`
2. **Copy token** from Settings screen
3. **Send FCM** from Firebase Console with test data
4. **Watch logs** for FCM handling messages
5. **Test different states** (foreground/background/closed)

---

## 🎯 **Expected Results**

### **✅ Success Indicators:**
- FCM token appears in Settings
- Debug logs show message received
- Call simulation logs appear
- App responds to notifications in all states

### **🔄 Next Steps After Testing:**
- Share results with your VoIP engineer
- Engineer integrates FCM sending into SIP server
- Test with real incoming calls
- Add CallKit native UI later

---

## 🚀 **Production Integration**

Once testing works, your SIP server will send notifications like this:

```json
{
  "to": "<user_fcm_token>",
  "priority": "high",
  "data": {
    "type": "incoming_call",
    "caller_id": "01687722962",
    "caller_name": "John Doe", 
    "call_uuid": "real_call_id_from_sip"
  }
}
```

**This gives you the same background call capability as WhatsApp! 📞🎉**