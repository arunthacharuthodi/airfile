package com.antigravity.airfile

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifi?.createMulticastLock("AirFileMulticastLock")?.apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}
