package com.example.zebra_scanner_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "zebra_scanner"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Verifica que flutterEngine no sea nulo antes de configurar el canal
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

        // Registro para recibir el Intent de DataWedge
        val filter = IntentFilter()
        filter.addAction("com.zebra.scanner.RETURN_BARCODE") // La acción que configuraste en DataWedge
        registerReceiver(receiver, filter)
    }

    private fun startScan() {
        // Enviar comando de inicio de escaneo a DataWedge
        val intent = Intent()
        intent.action = "com.symbol.datawedge.api.ACTION"
        intent.putExtra("com.symbol.datawedge.api.SOFT_SCAN_TRIGGER", "START_SCANNING")
        sendBroadcast(intent)
    }

    private val receiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.hasExtra("com.symbol.datawedge.data_string")) {
                val barcodeData = intent.getStringExtra("com.symbol.datawedge.data_string")
                // Verifica que flutterEngine no sea nulo antes de invocar el método
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