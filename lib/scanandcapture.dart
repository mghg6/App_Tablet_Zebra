import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

class ScanAndCapture extends StatefulWidget {
  @override
  _ScanAndCaptureState createState() => _ScanAndCaptureState();
}

class _ScanAndCaptureState extends State<ScanAndCapture>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('zebra_scanner');
  final List<Map<String, dynamic>> epcs = [];
  final List<File> images = [];
  bool isUploading = false;
  bool _isScanning = false;
  bool _isProcessing = false;
  final TextEditingController fechaController = TextEditingController();
  final TextEditingController operadorController = TextEditingController();
  final TextEditingController noLogisticaController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanner();
    platform.setMethodCallHandler(null);
    fechaController.dispose();
    operadorController.dispose();
    noLogisticaController.dispose();
    observacionesController.dispose();
    _clearAllData();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScanning) {
          _enableScanner();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopScanner();
        break;
    }
  }

  Future<void> _stopScanner() async {
    if (!mounted) return;

    try {
      await platform.invokeMethod('stopScan');
      _isScanning = false;
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnackBar("Error al detener escaneo: ${e.message}");
      }
    }
  }

  void _enableScanner() {
    if (!mounted) return;

    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned" && !_isProcessing && mounted) {
        _isProcessing = true;
        try {
          final rawCode =
              call.arguments.toString().split(RegExp(r'[ -]')).first;
          final formattedCode = rawCode.padLeft(16, '0');
          await _processEPC(formattedCode);
        } finally {
          _isProcessing = false;
        }
      }
      return null;
    });

    _isScanning = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enableScanner();
  }

  Future<void> startScanning() async {
    if (!mounted) return;

    try {
      await platform.invokeMethod('startScan');
      _isScanning = true;
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnackBar("Error al iniciar escaneo: ${e.message}");
      }
    }
  }

  // Método para seleccionar fotos de la galería
  Future<void> selectFromGallery() async {
    try {
      final List<XFile> selectedImages = await _imagePicker.pickMultiImage(
        imageQuality: 85, // Aumentamos la calidad
      );

      if (selectedImages.isNotEmpty && mounted) {
        for (XFile image in selectedImages) {
          final File originalImage = File(image.path);
          final optimizedImage = await _optimizeAndSaveImage(originalImage);

          if (optimizedImage != null && mounted) {
            setState(() {
              images.add(optimizedImage);
            });
            if (await originalImage.exists()) {
              await originalImage.delete();
            }
          }
        }
        _showSnackBar("${selectedImages.length} imágenes agregadas");
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error al cargar imágenes: ${e.toString()}");
    }
  }

  // EPC Processing with optimized memory management
  Future<void> _processEPC(String epc) async {
    if (epcs.any((e) => e['epc'] == epc)) {
      if (mounted) _showSnackBar("EPC ya escaneado");
      return;
    }

    try {
      final url = Uri.parse("http://172.16.10.31/api/Socket/$epc");
      final response = await http.get(url).timeout(
            Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Tiempo de espera agotado'),
          );

      if (response.statusCode == 200 && mounted) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
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
      } else {
        throw HttpException('Error en la respuesta del servidor');
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error al procesar EPC: ${e.toString()}");
    }
  }

  // Optimized image capture with memory management
  Future<void> captureImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Aumentamos la calidad de 50 a 85
        maxWidth: 2048, // Aumentamos el ancho máximo para mejor calidad
        maxHeight:
            1536, // Aumentamos el alto máximo manteniendo la relación 4:3
      );

      if (pickedFile != null && mounted) {
        final File originalImage = File(pickedFile.path);
        final optimizedImage = await _optimizeAndSaveImage(originalImage);

        if (optimizedImage != null && mounted) {
          setState(() {
            images.add(optimizedImage);
          });
          if (await originalImage.exists()) {
            await originalImage.delete();
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error al capturar imagen: ${e.toString()}");
    }
  }

  // Optimized image processing
  Future<File?> _optimizeAndSaveImage(File originalImage) async {
    try {
      final directory = await getTemporaryDirectory();
      final targetPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Obtenemos las dimensiones de la imagen original
      final decodedImage =
          await decodeImageFromList(await originalImage.readAsBytes());
      double width = decodedImage.width.toDouble();
      double height = decodedImage.height.toDouble();

      // Calculamos las nuevas dimensiones manteniendo el aspecto
      double maxDimension = 2048.0; // Máxima dimensión permitida
      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension) / width;
          width = maxDimension;
        } else {
          width = (width * maxDimension) / height;
          height = maxDimension;
        }
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        originalImage.path,
        targetPath,
        quality: 85, // Calidad más alta
        format: CompressFormat.jpeg,
        minWidth: width.round(),
        minHeight: height.round(),
        keepExif: true, // Mantener metadatos EXIF
      );

      if (result == null) throw Exception('Fallo en la optimización de imagen');
      return File(result.path);
    } catch (e) {
      print("Error en optimización de imagen: $e");
      return null;
    }
  }

  // Optimized data upload with batch processing
  Future<void> uploadData() async {
    if (epcs.isEmpty) {
      _showSnackBar("No hay EPCs para subir.");
      return;
    }

    if (fechaController.text.isEmpty ||
        operadorController.text.isEmpty ||
        noLogisticaController.text.isEmpty) {
      _showSnackBar("Por favor complete todos los campos requeridos.");
      return;
    }

    setState(() => isUploading = true);

    try {
      final request = await _createUploadRequest();
      final streamedResponse = await request.send().timeout(
            Duration(minutes: 5),
            onTimeout: () =>
                throw TimeoutException('Tiempo de espera agotado en la subida'),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await _handleSuccessfulUpload();
      } else {
        throw HttpException(
            'Error en la respuesta del servidor: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog("Error de conexión", "Detalles: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // Optimized upload request creation
  Future<http.MultipartRequest> _createUploadRequest() async {
    final url = Uri.parse("http://172.16.10.31/api/RegistrosLogistica/create");
    final request = http.MultipartRequest('POST', url);

    request.fields.addAll({
      'Fecha': fechaController.text,
      'NombreOperador': operadorController.text,
      'NumeroLogistica': noLogisticaController.text,
      'Observaciones': observacionesController.text,
      'FechaCreacion': DateTime.now().toIso8601String(),
      'Dispositivo': "ET40",
      'ListaEPCs': jsonEncode(epcs.map((epc) => epc['epc']).toList()),
    });

    for (var image in images) {
      if (await image.exists()) {
        request.files
            .add(await http.MultipartFile.fromPath('Fotos', image.path));
      }
    }

    return request;
  }

  // Optimized success handler with proper cleanup
  Future<void> _handleSuccessfulUpload() async {
    try {
      await _clearAllData();
      if (mounted) _showSnackBar("Datos subidos exitosamente");
    } catch (e) {
      print("Error en limpieza post-subida: $e");
    }
  }

  // Optimized data clearing
  Future<void> _clearAllData() async {
    try {
      final directory = await getTemporaryDirectory();
      if (await directory.exists()) {
        final files = directory.listSync();
        for (var file in files) {
          if (file is File) await file.delete();
        }
      }

      if (mounted) {
        setState(() {
          epcs.clear();
          images.clear();
          fechaController.clear();
          operadorController.clear();
          noLogisticaController.clear();
          observacionesController.clear();
        });
      }
    } catch (e) {
      print("Error en limpieza de datos: $e");
      throw e;
    }
  }

  void _showUploadConfirmationModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                TextField(
                  controller: fechaController,
                  decoration: InputDecoration(
                    labelText: "Fecha *",
                    hintText: "YYYY-MM-DD",
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        fechaController.text =
                            date.toIso8601String().split('T').first;
                      });
                    }
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  controller: operadorController,
                  decoration: InputDecoration(
                    labelText: "Operador *",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: noLogisticaController,
                  decoration: InputDecoration(
                    labelText: "No. Logística *",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: observacionesController,
                  decoration: InputDecoration(
                    labelText: "Observaciones",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                Text(
                  "* Campos requeridos",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
                SizedBox(height: 8),
                Text("Total de Fotos: ${images.length}",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text("EPCs escaneados: ${epcs.length}",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("Cancelar"),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title, style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Top action bar
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          onPressed: () => startScanning(),
                          icon: Icon(Icons.qr_code_scanner),
                          label: Text("Escanear EPC"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF46707E),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCounter("EPCs", epcs.length, Icons.list_alt),
                      _buildCounter(
                          "Fotos", images.length, Icons.photo_library),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                // Add this to prevent overflow
                child: Column(
                  children: [
                    // EPCs list
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: epcs.isEmpty
                          ? _buildEmptyState(
                              "No hay EPCs escaneados", Icons.qr_code)
                          : Column(
                              children: epcs
                                  .asMap()
                                  .entries
                                  .map((entry) =>
                                      _buildEPCCard(entry.value, entry.key))
                                  .toList(),
                            ),
                    ),

                    // Image gallery
                    SizedBox(
                      height: 140,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: images.isEmpty
                            ? _buildEmptyState(
                                "No hay fotos", Icons.photo_library)
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                // Agregamos caching para mejorar el rendimiento
                                cacheExtent: 1000, // Cache más imágenes
                                itemBuilder: (context, index) {
                                  // Usar Image.memory con caching
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      return _buildImageCard(
                                          images[index], index);
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Panel inferior con botones de acción
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Add this
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: captureImage,
                          icon: Icon(Icons.camera_alt),
                          label: Text("Tomar Foto"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF46707E),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: selectFromGallery,
                          icon: Icon(Icons.photo_library),
                          label: Text("Galería"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF46707E),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete("fotos"),
                          icon: Icon(Icons.delete_outline),
                          label: Text("Eliminar Fotos"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete("epcs"),
                          icon: Icon(Icons.delete_outline),
                          label: Text("Eliminar EPCs"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          isUploading ? null : _showUploadConfirmationModal,
                      icon: isUploading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.cloud_upload),
                      label: Text(
                        isUploading ? "Subiendo..." : "Subir Datos",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Widget para mostrar contadores
  Widget _buildCounter(String label, int count, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF46707E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Color(0xFF46707E)),
          SizedBox(width: 8),
          Text(
            "$label: $count",
            style: TextStyle(
              color: Color(0xFF46707E),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

// Widget para estados vacíos
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

// Widget para tarjetas de EPC
  Widget _buildEPCCard(Map<String, dynamic> epc, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF46707E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF46707E),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "EPC: ${epc['epc']}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text("Clave Producto: ${epc['claveProducto']}"),
                  Text("Producto: ${epc['nombreProducto']}"),
                  Text("Peso: ${epc['pesoNeto']} kg"),
                  Text("Piezas: ${epc['piezas']}"),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() {
                  epcs.removeAt(index);
                });
                _showSnackBar("EPC eliminado");
              },
            ),
          ],
        ),
      ),
    );
  }

  // Agregar estas variables en la clase
  static const int _itemsPerPage = 20;
  int _currentPage = 0;

// Modificar la lista de EPCs para usar paginación
  Widget _buildEPCsList() {
    if (epcs.isEmpty) {
      return _buildEmptyState("No hay EPCs escaneados", Icons.qr_code);
    }

    final int start = _currentPage * _itemsPerPage;
    final int end = math.min(start + _itemsPerPage, epcs.length);
    final List<Map<String, dynamic>> pageItems = epcs.sublist(start, end);

    return Column(
      children: [
        ...pageItems
            .asMap()
            .entries
            .map((entry) => _buildEPCCard(entry.value, start + entry.key))
            .toList(),
        if (epcs.length > _itemsPerPage)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                    '${_currentPage + 1}/${(epcs.length / _itemsPerPage).ceil()}'),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: (start + _itemsPerPage) < epcs.length
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

// Widget para tarjetas de imagen
  Widget _buildImageCard(File image, int index) {
    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                image,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 240, // Cache del doble del tamaño mostrado
                cacheHeight:
                    240, // Para mejor calidad en pantallas de alta densidad
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    images.removeAt(index);
                  });
                  _showSnackBar("Imagen eliminada");
                },
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Stack(
            children: [
              Image.file(
                image,
                fit: BoxFit.contain,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            type == "fotos"
                ? "¿Eliminar todas las fotos?"
                : "¿Eliminar todos los EPCs?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            type == "fotos"
                ? "Esto eliminará todas las fotos capturadas. ¿Desea continuar?"
                : "Esto eliminará todos los EPCs escaneados. ¿Desea continuar?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                if (type == "fotos") {
                  setState(() => images.clear());
                  _showSnackBar("Todas las fotos eliminadas");
                } else {
                  setState(() => epcs.clear());
                  _showSnackBar("Todos los EPCs eliminados");
                }
                Navigator.of(context).pop();
              },
              child: Text("Eliminar"),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }
}
