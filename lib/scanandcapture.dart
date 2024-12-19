import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ScanAndCapture extends StatefulWidget {
  @override
  _ScanAndCaptureState createState() => _ScanAndCaptureState();
}

class _ScanAndCaptureState extends State<ScanAndCapture> {
  static const platform = MethodChannel('zebra_scanner');
  List<Map<String, dynamic>> epcs = []; // Lista para múltiples EPCs
  List<File> images = [];
  bool isUploading = false;
  TextEditingController fechaController = TextEditingController();
  TextEditingController operadorController = TextEditingController();
  TextEditingController noLogisticaController = TextEditingController();
  TextEditingController observacionesController = TextEditingController();
  void _enableScanner() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        String rawCode = call.arguments.toString().split(RegExp(r'[ -]')).first;
        String formattedCode = rawCode.padLeft(16, '0');
        fetchEPCInfo(formattedCode);
      }
    });
  }

  void _showImagePreview(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Stack(
            children: [
              // Imagen a pantalla completa dentro de la modal
              Image.file(image, fit: BoxFit.contain),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Icon(Icons.close, color: Colors.red, size: 30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _disableScanner() {
    platform.setMethodCallHandler(null);
  }

  Future<void> startScanning() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      _showSnackBar("Error al iniciar escaneo: ${e.message}");
    }
  }

  Future<void> fetchEPCInfo(String epc) async {
    final url = Uri.parse("http://172.16.10.31/api/Socket/$epc");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print("Respuesta del servidor: ${response.body}");
        final data = Map<String, dynamic>.from(jsonDecode(response.body));

        // Añadir EPC escaneado a la lista
        setState(() {
          epcs.add({
            'epc': epc,
            'claveProducto': data['claveProducto'] ?? 'N/A',
            'nombreProducto': data['nombreProducto'] ?? 'N/A',
            'pesoNeto': data['pesoNeto']?.toString() ?? 'N/A',
            'piezas': data['piezas']?.toString() ?? 'N/A',
            'trazabilidad': data['trazabilidad'] ?? 'N/A',
          });
        });

        print("EPC procesado: ${epcs.last}");
      } else {
        _showSnackBar("Error al obtener datos del EPC.");
      }
    } catch (e) {
      _showSnackBar("Error de conexión al servidor.");
    }
  }

  Future<File?> compressImage(File file) async {
    try {
      // Ruta temporal para almacenar la imagen comprimida
      final directory = await getTemporaryDirectory();
      final targetPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      // Comprimir la imagen
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path, // Ruta del archivo original
        targetPath, // Ruta destino del archivo comprimido
        quality: 75, // Ajusta la calidad (0-100)
      );

      return result != null
          ? File(result.path)
          : null; // Convertir a File si es necesario
    } catch (e) {
      print("Error al comprimir la imagen: $e");
      return null;
    }
  }

  Future<void> captureImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        images.add(File(pickedFile.path));
      });
    }
  }

  void _showUploadConfirmationModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            // Envuelve todo el contenido
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Ajusta el tamaño
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Center(
                    child: Text(
                      "Confirmación de Datos",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF46707E),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Fecha
                  TextField(
                    controller: fechaController,
                    decoration: InputDecoration(
                      labelText: "Fecha",
                      hintText: "YYYY-MM-DD",
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          fechaController.text =
                              pickedDate.toIso8601String().split('T').first;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 8),

                  // Operador
                  TextField(
                    controller: operadorController,
                    decoration: InputDecoration(
                      labelText: "Operador",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),

                  // No. Logística
                  TextField(
                    controller: noLogisticaController,
                    decoration: InputDecoration(
                      labelText: "No. Logística",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),

                  // Observaciones
                  TextField(
                    controller: observacionesController,
                    decoration: InputDecoration(
                      labelText: "Observaciones",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),

                  // Información adicional
                  Text("Total de Fotos: ${images.length}",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Número de EPCs leídos: ${epcs.length}",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),

                  // Lista de trazabilidades
                  Text("Trazabilidades:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: epcs.length,
                      itemBuilder: (context, index) {
                        return Text("- ${epcs[index]['trazabilidad']}");
                      },
                    ),
                  ),
                  SizedBox(height: 16),

                  // Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Cancelar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          uploadData();
                        },
                        child: Text("Confirmar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF46707E),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> uploadData() async {
    if (epcs.isEmpty) {
      _showSnackBar("No hay EPCs para subir.");
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      final url =
          Uri.parse("http://172.16.10.31/api/RegistrosLogistica/create");
      final request = http.MultipartRequest('POST', url);

      // Agregar campos al request
      request.fields['Fecha'] = fechaController.text;
      request.fields['NombreOperador'] = operadorController.text;
      request.fields['NumeroLogistica'] = noLogisticaController.text;
      request.fields['Observaciones'] = observacionesController.text;
      request.fields['FechaCreacion'] = DateTime.now().toIso8601String();
      request.fields['Dispositivo'] = "Dispositivo Zebra 123";

      // Enviar cada EPC como un valor separado para el campo ListaEPCs
      // Enviar cada EPC como un valor separado para el campo ListaEPCs
      final epcList =
          epcs.map((epc) => epc['epc']).toList(); // Extrae solo los EPCs
      request.fields['ListaEPCs'] = jsonEncode(epcList);

      // Comprimir imágenes y añadirlas al request
      for (var image in images) {
        final compressedImage = await compressImage(image);
        if (compressedImage != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'Fotos',
            compressedImage.path,
          ));
        } else {
          print("No se pudo comprimir la imagen: ${image.path}");
        }
      }

      // Enviar solicitud
      final response = await request.send();

      if (response.statusCode == 200) {
        _showSnackBar("Datos subidos exitosamente.");
        setState(() {
          epcs.clear();
          images.clear();
        });
      } else {
        final responseBody = await response.stream.bytesToString();
        print("Error al subir los datos. Código: ${response.statusCode}");
        print("Detalles del error: $responseBody");
        _showSnackBar("Error al subir los datos.");
      }
    } catch (e) {
      print("Error de conexión o al procesar la solicitud: $e");
      _showSnackBar("Error de conexión al servidor.");
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.teal,
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: startScanning,
                icon: Icon(Icons.qr_code_scanner),
                label: Text("Escanear EPC"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF46707E),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Lista de EPCs ajustada automáticamente
              Expanded(
                flex: 2,
                child: ListView.builder(
                  itemCount: epcs.length,
                  itemBuilder: (context, index) {
                    final epc = epcs[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("RFID: ${epc['epc']}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("Clave Producto: ${epc['claveProducto']}"),
                            Text("Nombre Producto: ${epc['nombreProducto']}"),
                            Text("Peso Neto: ${epc['pesoNeto']}"),
                            Text("Piezas: ${epc['piezas']}"),
                            Text("Trazabilidad: ${epc['trazabilidad']}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              // Lista de imágenes ajustada automáticamente
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: images
                        .map((image) => GestureDetector(
                              onTap: () {
                                _showImagePreview(image);
                              },
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(image,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    right: 5,
                                    top: 5,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          images.remove(image);
                                        });
                                      },
                                      child: Icon(Icons.close,
                                          color: Colors.red, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Botones para tomar foto y subir datos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: captureImage,
                    icon: Icon(Icons.camera_alt),
                    label: Text(
                      "Tomar Foto",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF46707E),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isUploading ? null : _showUploadConfirmationModal,
                    child: isUploading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            "Subir Datos",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
