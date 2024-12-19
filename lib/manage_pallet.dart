import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManagePallet extends StatefulWidget {
  @override
  _ManagePalletState createState() => _ManagePalletState();
}

class _ManagePalletState extends State<ManagePallet> {
  static const platform = MethodChannel('zebra_scanner');
  String scannedCode = 'Escanee un código de barras';
  Map<String, dynamic>? productData;
  bool isLoading = false;
  String? imageBase64;
  String? selectedAction;
  final String defaultImage =
      'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';
  final List<String> actions = [
    'Mandar a Histórico',
    'Mandar a Eliminar',
  ];

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        String rawCode = call.arguments.toString().split(RegExp(r'[ -]')).first;

        if (rawCode.length == 13) {
          scannedCode = '000$rawCode';
        } else {
          scannedCode = rawCode.padLeft(16, '0');
        }

        print("Código escaneado: $scannedCode");
        fetchProductData(scannedCode);
      }
    });
  }

  Future<void> iniciarEscaneo() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      setState(() {
        scannedCode = "Error: ${e.message}";
      });
      print("Error al iniciar el escaneo: ${e.message}");
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
        print("Datos del producto obtenidos: ${response.body}");
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
        print(
            "Producto no encontrado. Código de estado: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        productData = null;
        scannedCode = "Error al obtener datos del producto";
        imageBase64 = null;
      });
      print("Error al obtener datos del producto: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updatePalletStatus(int status) async {
    // Validamos que productData contenga el campo 'trazabilidad'
    final trazabilidad = productData?['trazabilidad'];
    if (trazabilidad == null || trazabilidad.isEmpty) {
      print("Error: No se encontró la trazabilidad en los datos del producto.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('No se encontró la trazabilidad en los datos del producto.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse(
        "http://172.16.10.31/api/HistoricoStatus/UpdateStatusByTrazabilidad/$trazabilidad");

    setState(() {
      isLoading = true;
    });

    try {
      print("Realizando PUT a: $url");
      print("Cuerpo de la solicitud: ${jsonEncode({'status': status})}");

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'text/plain',
        },
        body: jsonEncode({'status': status}),
      );

      print("Respuesta del servidor: ${response.statusCode}");
      print("Cuerpo de la respuesta: ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estatus actualizado a $status correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final responseBody = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error al actualizar el estatus: ${responseBody['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error al realizar el PUT: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al actualizar el estatus'),
          backgroundColor: Colors.red,
        ),
      );
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
          print("Imagen del producto obtenida correctamente.");
        }
      } else {
        setState(() {
          imageBase64 = null;
        });
        print("Imagen no encontrada. Código de estado: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        imageBase64 = null;
      });
      print("Error al obtener la imagen del producto: $e");
    }
  }

  Future<void> _postComment(
      String epc, String comentario, int status, String operador) async {
    final url = Uri.parse("http://172.16.10.31/api/ComentariosRFID");

    final body = {
      "epc": epc,
      "comentario": comentario,
      "status": status,
      "operador": operador,
    };

    try {
      print("Realizando POST a: $url");
      print("Cuerpo de la solicitud: ${jsonEncode(body)}");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'text/plain',
        },
        body: jsonEncode(body),
      );

      print("Respuesta del servidor: ${response.statusCode}");
      print("Cuerpo de la respuesta: ${response.body}");

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comentario registrado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar comentario.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error al realizar el POST: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al registrar el comentario.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmationDialog(int status) {
    final TextEditingController comentarioController = TextEditingController();
    final TextEditingController operadorController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Acción'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: comentarioController,
                decoration: InputDecoration(
                  labelText: 'Comentario',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              TextField(
                controller: operadorController,
                decoration: InputDecoration(
                  labelText: 'Operador',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                final comentario = comentarioController.text;
                final operador = operadorController.text;

                if (comentario.isEmpty || operador.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Debe completar todos los campos.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final trazabilidad = productData?['trazabilidad'];
                if (trazabilidad != null) {
                  _postComment(trazabilidad, comentario, status, operador);
                  updatePalletStatus(status);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trazabilidad no encontrada.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

                Navigator.of(context).pop();
              },
              child: Text('Confirmar'),
            ),
          ],
        );
      },
    );
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
        Text("Trazabilidad: ${productData?['trazabilidad'] ?? 'N/A'}"),
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
                          Text(
                            'Gestión de Tarima',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 15),
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
                          SizedBox(height: 20),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: selectedAction,
                            hint: Text('Seleccione una acción'),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedAction = newValue;
                              });
                            },
                            items: actions
                                .map<DropdownMenuItem<String>>(
                                    (String value) => DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        ))
                                .toList(),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (productData == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Escanee un código primero para obtener los datos del producto'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    if (selectedAction ==
                                        'Mandar a Histórico') {
                                      _showConfirmationDialog(6);
                                    } else if (selectedAction ==
                                        'Mandar a Eliminar') {
                                      _showConfirmationDialog(9);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Seleccione una acción válida'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF46707E),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Ejecutar Acción',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
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
