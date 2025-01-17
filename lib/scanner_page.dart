// lib/scanner_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils/scanner_state_mixin.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({Key? key}) : super(key: key);

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with WidgetsBindingObserver, ScannerStateMixin {
  static const Color primaryColor = Color(0xFF46707E);
  static const Color backgroundColor = Color(0xFFE8F1F2);

  String _scannedCode = 'Escanee un código de barras';
  Map<String, dynamic>? _productData;
  bool _isLoading = false;
  bool _isScannerActive = false;
  String? _imageBase64;
  final String _defaultImage =
      'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activateScanner(); // Activamos el scanner directamente
  }

  @override
  void dispose() {
    _deactivateScanner();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScannerActive) {
          _activateScanner();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _deactivateScanner();
        break;
    }
  }

  void _activateScanner() {
    if (!mounted) return;

    _isScannerActive = true;
    onViewMounted();
  }

  void _deactivateScanner() {
    if (!mounted) return;

    _isScannerActive = false;
    onViewUnmounted();
  }

  @override
  void onScanComplete(String code) async {
    if (!mounted) return;
    await _fetchProductData(code);
  }

  Future<void> _fetchProductData(String epc) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _scannedCode = "Buscando producto...";
    });

    try {
      final response = await http
          .get(Uri.parse("http://172.16.10.31/api/Socket/$epc"))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _productData = data;
          _scannedCode = "Producto encontrado";
        });

        if (data['productPrintCard'] != null) {
          await _fetchProductImage(data['productPrintCard']);
        }
      } else {
        _handleError("Producto no encontrado");
      }
    } catch (e) {
      _handleError("Error de conexión: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProductImage(String productPrintCard) async {
    try {
      final response = await http
          .get(Uri.parse("http://172.16.10.31/api/Image/$productPrintCard"))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? base64Data = data['imageBase64'];

        if (base64Data != null) {
          base64Data = base64Data.replaceFirst("data:image/jpeg;base64,", "");
          setState(() => _imageBase64 = base64Data);
        }
      }
    } catch (e) {
      print('Error fetching image: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      _productData = null;
      _scannedCode = message;
      _imageBase64 = null;
    });
    _showErrorSnackBar(message);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildProductInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildProductContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductContent() {
    if (_productData == null) {
      return Center(
        child: Text(
          _scannedCode,
          style: const TextStyle(
            fontSize: 20,
            color: primaryColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          "Producto",
          _productData?['nombreProducto'],
          fontSize: 18,
          isBold: true,
        ),
        const SizedBox(height: 16),
        _buildInfoRow("Área", _productData?['area']),
        _buildInfoRow("Clave de Producto", _productData?['claveProducto']),
        _buildInfoRow("Operador", _productData?['operador']),
        _buildInfoRow("Turno", _productData?['turno']),
        _buildInfoRow("Peso Neto", "${_productData?['pesoNeto']} kg"),
        _buildInfoRow("Piezas", _productData?['piezas']),
        _buildInfoRow("Unidad de Medida", _productData?['uom']),
        _buildInfoRow("Orden", _productData?['orden']),
        _buildInfoRow("Status", _productData?['status']),
        _buildInfoRow("Fecha de Creación", _productData?['createdAt']),
        const SizedBox(height: 20),
        Center(
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _imageBase64 != null
                  ? Image.memory(
                      base64Decode(_imageBase64!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.network(_defaultImage, fit: BoxFit.contain),
                    )
                  : Image.network(
                      _defaultImage,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    dynamic value, {
    double fontSize = 16,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildProductInfoCard(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        try {
                          await startScanning();
                        } catch (e) {
                          _showErrorSnackBar(e.toString());
                        }
                      },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: Text(
                  _isLoading ? 'Procesando...' : 'Iniciar Escaneo',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 6,
                  disabledBackgroundColor: primaryColor.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
