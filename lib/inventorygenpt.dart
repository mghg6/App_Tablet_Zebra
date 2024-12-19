import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InventoryGenPT extends StatefulWidget {
  @override
  _InventoryGenPTState createState() => _InventoryGenPTState();
}

class _InventoryGenPTState extends State<InventoryGenPT> {
  static const platform = MethodChannel('zebra_scanner');
  List<Map<String, dynamic>> scannedTags = [];
  String lastScannedTag = "Escanea una etiqueta";
  bool isLoading = false;

  // Controladores de texto para el formulario
  final TextEditingController fechaInventarioController =
      TextEditingController();
  final TextEditingController operadorController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController nombreArchivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enableScanner();
  }

  @override
  void dispose() {
    _disableScanner();
    // Libera los controladores
    fechaInventarioController.dispose();
    operadorController.dispose();
    ubicacionController.dispose();
    nombreArchivoController.dispose();
    super.dispose();
  }

  void _enableScanner() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        String rawCode = call.arguments.toString();

        // Extraer hasta el primer espacio o guion
        String extractedCode = rawCode.split(RegExp(r'[ -]')).first;

        // Validar y completar el EPC con ceros
        String formattedCode = extractedCode.length < 16
            ? extractedCode.padLeft(16, '0')
            : extractedCode;

        print("Código escaneado bruto: $rawCode");
        print("Código extraído: $extractedCode");
        print("EPC formateado: $formattedCode");

        if (!scannedTags.any((tag) => tag['trazabilidad'] == formattedCode)) {
          setState(() {
            lastScannedTag = "Última etiqueta: $formattedCode";
          });

          // Llamar a fetchPalletData para obtener la información
          fetchPalletData(formattedCode);
        } else {
          setState(() {
            lastScannedTag = "Etiqueta ya escaneada: $formattedCode";
          });
          print("Etiqueta ya escaneada: $formattedCode");
        }
      }
    });
  }

  void _disableScanner() {
    platform.setMethodCallHandler(null);
  }

  Future<void> fetchPalletData(String epc) async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse("http://172.16.10.31/api/Socket/$epc");
    print("Iniciando petición con EPC: $epc");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data != null) {
          // Extraer la información requerida
          final tagInfo = {
            'claveProducto': data['claveProducto'] ?? 'N/A',
            'pesoNeto': data['pesoNeto'] ?? 'N/A',
            'piezas': data['piezas'] ?? 'N/A',
            'trazabilidad': epc,
          };

          print("Información de la etiqueta escaneada: $tagInfo");

          setState(() {
            scannedTags.add(tagInfo);
            lastScannedTag = "Etiqueta agregada: $epc";
          });
        }
      } else {
        print("Petición fallida: Código de respuesta ${response.statusCode}");
        setState(() {
          lastScannedTag = "Tarima no encontrada";
        });
      }
    } catch (e) {
      print("Error durante la petición: $e");
      setState(() {
        lastScannedTag = "Error al obtener datos de la tarima";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
      print("Petición completada.");
    }
  }

  Future<void> enviarInformacion() async {
    final List<String> epcs =
        scannedTags.map((tag) => tag['trazabilidad'] as String).toList();

    final body = {
      "epcs": epcs,
      "fechaInventario": fechaInventarioController.text,
      "formatoEtiqueta": "Inventario",
      "operador": operadorController.text,
      "ubicacion": ubicacionController.text,
      "nombreArchivo": nombreArchivoController.text,
    };

    final url = Uri.parse(
        "http://172.16.10.31/api/RfidLabel/generate-excel-from-handheld-save-inventory");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "accept": "*/*",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("Datos enviados correctamente: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Información enviada correctamente")),
        );
      } else {
        print("Error al enviar datos: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al enviar datos")),
        );
      }
    } catch (e) {
      print("Error durante la solicitud: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error durante la solicitud")),
      );
    }
  }

  void mostrarFormularioEnvio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enviar Información"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    setState(() {
                      fechaInventarioController.text =
                          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    });
                  }
                },
                child: TextField(
                  controller: fechaInventarioController,
                  decoration: InputDecoration(
                    labelText: "Fecha de Inventario",
                    hintText: "YYYY-MM-DD",
                  ),
                  enabled: false, // Evita que se edite manualmente
                ),
              ),
              TextField(
                controller: operadorController,
                decoration: InputDecoration(labelText: "Operador"),
              ),
              TextField(
                controller: ubicacionController,
                decoration: InputDecoration(labelText: "Ubicación"),
              ),
              TextField(
                controller: nombreArchivoController,
                decoration: InputDecoration(labelText: "Nombre del Archivo"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              enviarInformacion();
            },
            child: Text("Enviar"),
          ),
        ],
      ),
    );
  }

  Widget buildProductList() {
    if (scannedTags.isEmpty) {
      return Center(
        child: Text(
          "No hay etiquetas escaneadas.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: scannedTags.length,
      itemBuilder: (context, index) {
        final tag = scannedTags[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: ListTile(
            title: Text(
              "Clave Producto: ${tag['claveProducto']}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Peso Neto: ${tag['pesoNeto']} kg"),
                Text("Piezas: ${tag['piezas']}"),
                Text("Trazabilidad: ${tag['trazabilidad']}"),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastScannedTag,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "Total etiquetas escaneadas: ${scannedTags.length}",
              style: TextStyle(fontSize: 18, color: Colors.teal),
            ),
            SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : buildProductList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: mostrarFormularioEnvio,
        backgroundColor: Colors.teal,
        child: Icon(Icons.add),
      ),
    );
  }
}
