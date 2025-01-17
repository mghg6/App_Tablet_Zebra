// lib/utils/scanner_state_mixin.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

enum ScannerState { enabled, disabled, scanning }

mixin ScannerStateMixin<T extends StatefulWidget> on State<T> {
  static const MethodChannel platform = MethodChannel('zebra_scanner');
  ScannerState _scannerState = ScannerState.disabled;
  bool _isViewMounted = false;

  // Method to start scanning
  Future<void> startScanning() async {
    if (_scannerState == ScannerState.scanning || !_isViewMounted) return;

    try {
      await platform.invokeMethod('startScan');
      _scannerState = ScannerState.scanning;
    } on PlatformException catch (e) {
      throw Exception("Error al iniciar escaneo: ${e.message}");
    }
  }

  // Method to stop scanning
  Future<void> stopScanning() async {
    if (_scannerState != ScannerState.scanning) return;

    try {
      await platform.invokeMethod('stopScan');
      _scannerState = ScannerState.enabled;
    } on PlatformException catch (e) {
      throw Exception("Error al detener escaneo: ${e.message}");
    }
  }

  void onViewMounted() {
    _isViewMounted = true;
    if (_scannerState == ScannerState.disabled) {
      _initializeScanner();
    }
  }

  void onViewUnmounted() {
    _isViewMounted = false;
    _disableScanner();
  }

  Future<void> _initializeScanner() async {
    if (!_isViewMounted) return;
    await _enableScanner();
  }

  Future<void> _enableScanner() async {
    if (_scannerState == ScannerState.enabled || !_isViewMounted) return;

    try {
      await platform.invokeMethod('registerListener');

      platform.setMethodCallHandler((call) async {
        if (call.method == "barcodeScanned" && _isViewMounted) {
          final rawCode =
              call.arguments.toString().split(RegExp(r'[ -]')).first;
          final formattedCode =
              rawCode.length == 13 ? '000$rawCode' : rawCode.padLeft(16, '0');
          onScanComplete(formattedCode);
        }
      });

      _scannerState = ScannerState.enabled;
    } on PlatformException catch (e) {
      throw Exception("Error al inicializar escáner: ${e.message}");
    }
  }

  Future<void> _disableScanner() async {
    if (_scannerState == ScannerState.disabled) return;

    try {
      if (_scannerState == ScannerState.scanning) {
        await stopScanning();
      }
      await platform.invokeMethod('unregisterListener');
      platform.setMethodCallHandler(null);
      _scannerState = ScannerState.disabled;
    } on PlatformException catch (e) {
      throw Exception("Error al desactivar escáner: ${e.message}");
    }
  }

  // Abstract method to be implemented by classes using this mixin
  void onScanComplete(String code);

  @override
  void dispose() {
    _disableScanner();
    super.dispose();
  }
}
