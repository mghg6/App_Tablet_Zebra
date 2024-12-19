import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  static const platform = MethodChannel('zebra_scanner');
  String scannedCode = 'Escanee un código de barras';
  Map<String, dynamic>? productData;
  bool isLoading = false;
  String? imageBase64;
  final String defaultImage =
      'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';

  @override
  void initState() {
    super.initState();
    _enableScanner();
  }

  @override
  void dispose() {
    _disableScanner();
    super.dispose();
  }

  void _enableScanner() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        String rawCode = call.arguments.toString().split(RegExp(r'[ -]')).first;

        if (rawCode.length == 13) {
          scannedCode = '000$rawCode';
        } else {
          scannedCode = rawCode.padLeft(16, '0');
        }

        fetchProductData(scannedCode);
      }
    });
  }

  void _disableScanner() {
    platform.setMethodCallHandler(null); // Limpia el controlador
  }

  Future<void> iniciarEscaneo() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      setState(() {
        scannedCode = "Error: ${e.message}";
      });
    }
  }

  Future<void> fetchProductData(String epc) async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse("http://172.16.10.31/api/Socket/$epc");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          productData = jsonDecode(response.body);
          scannedCode = "Producto encontrado";
        });
        final productPrintCard = productData?['productPrintCard'];
        if (productPrintCard != null) {
          fetchProductImage(productPrintCard);
        }
      } else {
        setState(() {
          productData = null;
          scannedCode = "Producto no encontrado";
          imageBase64 = null;
        });
      }
    } catch (e) {
      setState(() {
        productData = null;
        scannedCode = "Error al obtener datos del producto";
        imageBase64 = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchProductImage(String productPrintCard) async {
    final url = Uri.parse("http://172.16.10.31/api/Image/$productPrintCard");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData != null && responseData['imageBase64'] != null) {
          String base64Data = responseData['imageBase64'];
          if (base64Data.startsWith("data:image/jpeg;base64,")) {
            base64Data = base64Data.replaceFirst("data:image/jpeg;base64,", "");
          }
          setState(() {
            imageBase64 = base64Data;
          });
        }
      } else {
        setState(() {
          imageBase64 = null;
        });
      }
    } catch (e) {
      setState(() {
        imageBase64 = null;
      });
    }
  }

  Widget buildProductInfo() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (productData == null) {
      return Text(
        scannedCode,
        style: TextStyle(fontSize: 20, color: Color(0xFF46707E)),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Producto: ${productData?['nombreProducto'] ?? 'N/A'}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("Área: ${productData?['area'] ?? 'N/A'}"),
        Text("Clave de Producto: ${productData?['claveProducto'] ?? 'N/A'}"),
        Text("Operador: ${productData?['operador'] ?? 'N/A'}"),
        Text("Turno: ${productData?['turno'] ?? 'N/A'}"),
        Text("Peso Neto: ${productData?['pesoNeto'] ?? 'N/A'} kg"),
        Text("Piezas: ${productData?['piezas'] ?? 'N/A'}"),
        Text("Unidad de Medida: ${productData?['uom'] ?? 'N/A'}"),
        Text("Orden: ${productData?['orden'] ?? 'N/A'}"),
        Text("Status: ${productData?['status'] ?? 'N/A'}"),
        Text("Fecha de Creación: ${productData?['createdAt'] ?? 'N/A'}"),
        SizedBox(height: 16),
        Center(
          child: imageBase64 != null
              ? Image.memory(
                  base64Decode(imageBase64!),
                  height: 200,
                )
              : Image.network(
                  defaultImage,
                  height: 200,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Color(0xFFE8F1F2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Color(0xFF46707E), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: buildProductInfo(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding > 0 ? bottomPadding : 16.0,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: iniciarEscaneo,
                    icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: Text(
                      'Iniciar Escaneo',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF46707E),
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
