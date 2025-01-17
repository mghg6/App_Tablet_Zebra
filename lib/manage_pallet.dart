import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Constants
const String API_BASE_URL = 'http://172.16.10.31/api';
const String DEFAULT_IMAGE =
    'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';
const Color PRIMARY_COLOR = Color(0xFF46707E);
const Color BACKGROUND_COLOR = Color(0xFFE8F1F2);

// Enums for better type safety
enum PalletAction { historic, delete }

// Models
@immutable
class ProductData {
  final String nombreProducto;
  final String area;
  final String claveProducto;
  final String operador;
  final String turno;
  final String pesoNeto;
  final String piezas;
  final String uom;
  final String orden;
  final String status;
  final String trazabilidad;
  final String? productPrintCard;
  final String? createdAt;

  const ProductData({
    required this.nombreProducto,
    required this.area,
    required this.claveProducto,
    required this.operador,
    required this.turno,
    required this.pesoNeto,
    required this.piezas,
    required this.uom,
    required this.orden,
    required this.status,
    required this.trazabilidad,
    this.productPrintCard,
    this.createdAt,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) => ProductData(
        nombreProducto: json['nombreProducto'] ?? 'N/A',
        area: json['area'] ?? 'N/A',
        claveProducto: json['claveProducto'] ?? 'N/A',
        operador: json['operador'] ?? 'N/A',
        turno: json['turno'] ?? 'N/A',
        pesoNeto: json['pesoNeto']?.toString() ?? 'N/A',
        piezas: json['piezas']?.toString() ?? 'N/A',
        uom: json['uom'] ?? 'N/A',
        orden: json['orden'] ?? 'N/A',
        status: json['status']?.toString() ?? 'N/A',
        trazabilidad: json['trazabilidad'] ?? '',
        productPrintCard: json['productPrintCard'],
        createdAt: json['createdAt'],
      );
}

@immutable
class CommentData {
  final String epc;
  final String comentario;
  final int status;
  final String operador;

  const CommentData({
    required this.epc,
    required this.comentario,
    required this.status,
    required this.operador,
  });

  Map<String, dynamic> toJson() => {
        'epc': epc,
        'comentario': comentario,
        'status': status,
        'operador': operador,
      };
}

// API Service class for better separation of concerns
class PalletApiService {
  static final client = http.Client();

  static Future<ProductData> fetchProductData(String epc) async {
    final response = await client.get(
      Uri.parse('$API_BASE_URL/Socket/$epc'),
      headers: {'accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return ProductData.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch product data');
  }

  static Future<String?> fetchProductImage(String productPrintCard) async {
    final response = await client.get(
      Uri.parse('$API_BASE_URL/Image/$productPrintCard'),
      headers: {'accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData?['imageBase64'] != null) {
        return responseData['imageBase64']
            .replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');
      }
    }
    return null;
  }

  static Future<void> updatePalletStatus(
      String trazabilidad, int status) async {
    final response = await client.put(
      Uri.parse(
          '$API_BASE_URL/HistoricoStatus/UpdateStatusByTrazabilidad/$trazabilidad'),
      headers: {
        'Content-Type': 'application/json',
        'accept': 'text/plain',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update status');
    }
  }

  static Future<void> postComment(CommentData commentData) async {
    final response = await client.post(
      Uri.parse('$API_BASE_URL/ComentariosRFID'),
      headers: {
        'Content-Type': 'application/json',
        'accept': 'text/plain',
      },
      body: jsonEncode(commentData.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to post comment');
    }
  }
}

class ManagePallet extends StatefulWidget {
  const ManagePallet({Key? key}) : super(key: key);

  @override
  _ManagePalletState createState() => _ManagePalletState();
}

class _ManagePalletState extends State<ManagePallet>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('zebra_scanner');
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // State variables
  String _scannedCode = 'Escanee un código de barras';
  ProductData? _productData;
  bool _isLoading = false;
  bool _isScannerActive = false;
  String? _imageBase64;
  PalletAction? _selectedAction;
  final _commentController = TextEditingController();
  final _operatorController = TextEditingController();

  // Lifecycle methods
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activateScanner();
  }

  @override
  void deactivate() {
    _deactivateScanner();
    super.deactivate();
  }

  @override
  void dispose() {
    _deactivateScanner();
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    _operatorController.dispose();
    platform.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScannerActive) _activateScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _deactivateScanner();
        break;
    }
  }

  // Scanner methods
  void _activateScanner() {
    if (!mounted) return;

    _isScannerActive = true;
    platform.setMethodCallHandler((call) async {
      if (!mounted) return;

      if (call.method == "barcodeScanned") {
        final rawCode = call.arguments.toString().split(RegExp(r'[ -]')).first;
        final formattedCode =
            rawCode.length == 13 ? '000$rawCode' : rawCode.padLeft(16, '0');
        await _handleScannedCode(formattedCode);
      }
    });
  }

  void _deactivateScanner() {
    if (!mounted) return;
    _isScannerActive = false;
    platform.setMethodCallHandler(null);
  }

  Future<void> _startScan() async {
    if (!mounted || !_isScannerActive) return;

    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      if (mounted) {
        _showErrorSnackBar("Error al iniciar escaneo: ${e.message}");
      }
    }
  }

  Future<void> _refreshData() async {
    if (_productData?.trazabilidad != null) {
      await _handleScannedCode(_productData!.trazabilidad);
    }
  }

  // Data handling methods
  Future<void> _handleScannedCode(String code) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _scannedCode = "Buscando producto...";
    });

    try {
      final productData = await PalletApiService.fetchProductData(code);

      if (!mounted) return;

      setState(() {
        _productData = productData;
        _scannedCode = "Producto encontrado";
      });

      if (productData.productPrintCard != null) {
        final imageBase64 = await PalletApiService.fetchProductImage(
            productData.productPrintCard!);
        if (mounted) setState(() => _imageBase64 = imageBase64);
      }
    } catch (e) {
      if (mounted) {
        _resetState("Error al obtener datos del producto");
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleActionExecution() async {
    if (!mounted || _productData == null || _selectedAction == null) return;

    if (_commentController.text.isEmpty || _operatorController.text.isEmpty) {
      _showErrorSnackBar('Debe completar todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final status = _selectedAction == PalletAction.historic ? 6 : 9;

      final commentData = CommentData(
        epc: _productData!.trazabilidad,
        comentario: _commentController.text,
        status: status,
        operador: _operatorController.text,
      );

      await Future.wait([
        PalletApiService.postComment(commentData),
        PalletApiService.updatePalletStatus(_productData!.trazabilidad, status),
      ]);

      if (!mounted) return;

      _showSuccessSnackBar('Acción ejecutada correctamente');
      _clearForm();
      await _refreshData();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al ejecutar la acción: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper methods
  void _resetState(String message) {
    setState(() {
      _productData = null;
      _scannedCode = message;
      _imageBase64 = null;
      _selectedAction = null;
    });
  }

  void _clearForm() {
    _commentController.clear();
    _operatorController.clear();
    setState(() => _selectedAction = null);
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  } // UI Components

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMainCard(),
                    if (_productData != null) ...[
                      const SizedBox(height: 20),
                      _buildActionSelector(),
                      const SizedBox(height: 20),
                      _buildActionButton(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BACKGROUND_COLOR,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: PRIMARY_COLOR, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _buildProductInfo(),
    );
  }

  Widget _buildProductInfo() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(PRIMARY_COLOR),
        ),
      );
    }

    if (_productData == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _scannedCode,
            style: const TextStyle(
              fontSize: 20,
              color: PRIMARY_COLOR,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _startScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Iniciar Escaneo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PRIMARY_COLOR,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 16),
          _buildImageSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Producto", _productData!.nombreProducto,
                isTitle: true),
            const Divider(height: 24),
            _buildInfoRow("Área", _productData!.area),
            _buildInfoRow("Clave de Producto", _productData!.claveProducto),
            _buildInfoRow("Operador", _productData!.operador),
            _buildInfoRow("Turno", _productData!.turno),
            _buildInfoRow("Peso Neto", "${_productData!.pesoNeto} kg"),
            _buildInfoRow("Piezas", _productData!.piezas),
            _buildInfoRow("Unidad de Medida", _productData!.uom),
            _buildInfoRow("Orden", _productData!.orden),
            _buildInfoRow("Status", _productData!.status),
            _buildInfoRow("Trazabilidad", _productData!.trazabilidad),
            if (_productData!.createdAt != null)
              _buildInfoRow("Fecha de Creación", _productData!.createdAt!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTitle = false}) {
    final TextStyle baseStyle = TextStyle(
      fontSize: isTitle ? 18 : 14,
      fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
      color: isTitle ? PRIMARY_COLOR : Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: baseStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: baseStyle.copyWith(
                fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: DecoratedBox(
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
            child: _buildImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_imageBase64 != null) {
      return Image.memory(
        base64Decode(_imageBase64!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildImageError(),
      );
    }

    return Image.network(
      DEFAULT_IMAGE,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (_, __, ___) => _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Error al cargar la imagen',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSelector() {
    return DropdownButtonFormField<PalletAction>(
      value: _selectedAction,
      decoration: InputDecoration(
        labelText: 'Seleccione una acción',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(
          value: PalletAction.historic,
          child: Text('Mandar a Histórico'),
        ),
        DropdownMenuItem(
          value: PalletAction.delete,
          child: Text('Mandar a Eliminar'),
        ),
      ],
      onChanged: (PalletAction? value) {
        setState(() => _selectedAction = value);
      },
    );
  }

  Widget _buildActionButton() {
    return AnimatedOpacity(
      opacity: _selectedAction != null ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: _isLoading || _selectedAction == null
            ? null
            : () => _showConfirmationDialog(
                _selectedAction == PalletAction.historic ? 6 : 9),
        style: ElevatedButton.styleFrom(
          backgroundColor: PRIMARY_COLOR,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Ejecutar Acción',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _showConfirmationDialog(int status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          status == 6 ? 'Confirmar envío a Histórico' : 'Confirmar eliminación',
          style: const TextStyle(color: PRIMARY_COLOR),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(
              controller: _commentController,
              label: 'Comentario',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDialogTextField(
              controller: _operatorController,
              label: 'Operador',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleActionExecution();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PRIMARY_COLOR,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: maxLines,
    );
  }
}
