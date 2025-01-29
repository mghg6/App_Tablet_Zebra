package com.example.zebra_scanner_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "zebra_scanner"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        }

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "startScan") {
                    startScan()
                    result.success("Escaneo iniciado")
                } else {
                    result.notImplemented()
                }
            }
        }
        val filter = IntentFilter()
        filter.addAction("com.zebra.scanner.RETURN_BARCODE")
        registerReceiver(receiver, filter)
    }

    private fun startScan() {
        val intent = Intent()
        intent.action = "com.symbol.datawedge.api.ACTION"
        intent.putExtra("com.symbol.datawedge.api.SOFT_SCAN_TRIGGER", "START_SCANNING")
        sendBroadcast(intent)
    }

    private val receiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.hasExtra("com.symbol.datawedge.data_string")) {
                val barcodeData = intent.getStringExtra("com.symbol.datawedge.data_string")
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL)
                        .invokeMethod("barcodeScanned", barcodeData)
                }
            }
        }
    }

    override fun onDestroy() {
        unregisterReceiver(receiver)
        super.onDestroy()
    }
}