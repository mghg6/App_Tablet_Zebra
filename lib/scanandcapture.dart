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
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
// Añadir prefijo 'xl' a la importación de Excel
import 'package:excel/excel.dart' as xl;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http_parser/http_parser.dart';

class ScanAndCapture extends StatefulWidget {
  final int? reviewId;
  final int? noLogistica;
  final String? cliente;
  final String? operador;
  final List<String>? trazabilidadesList;
  final bool aduanaReview;
  final String? reviewStatus;
  final String? previousStatus; // Estado anterior

  ScanAndCapture({
    Key? key,
    this.reviewId,
    this.noLogistica,
    this.cliente,
    this.operador,
    this.trazabilidadesList,
    this.aduanaReview = false,
    this.reviewStatus,
    this.previousStatus,
  }) : super(key: key);
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
  bool isLoading = false;
  // Campos adicionales para la revisión de aduana
  final TextEditingController documentacionController = TextEditingController();
  bool isAduanaReview = false;

  // Variables para el checklist de aduana
  Map<String, bool> aduanaChecklist = {
    'documentacion_correcta': false,
    'sellos_completos': false,
    'embalaje_correcto': false,
    'etiquetado_aduana_correcto': false,
    'peso_bruto_correcto': false
  };

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableScanner();

    // Inicializar con los datos de revisión de aduana si los hay
    isAduanaReview = widget.aduanaReview;

    // Si tenemos trazabilidades, cargarlas
    if (widget.trazabilidadesList != null &&
        widget.trazabilidadesList!.isNotEmpty) {
      _loadInitialEPCs();
    }

    // Si tenemos datos de la logística, inicializar los campos
    if (widget.noLogistica != null) {
      noLogisticaController.text = widget.noLogistica.toString();
    }

    if (widget.operador != null) {
      operadorController.text = widget.operador.toString();
    }

    // Establecer la fecha actual
    fechaController.text = DateTime.now().toIso8601String().split('T')[0];
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
    documentacionController.dispose();
    _clearAllData();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScanning) _enableScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopScanner();
        break;
    }
  }

  Future<void> _loadInitialEPCs() async {
    if (widget.trazabilidadesList == null || widget.trazabilidadesList!.isEmpty)
      return;

    setState(() => isLoading = true);

    for (String trazabilidad in widget.trazabilidadesList!) {
      try {
        // Limpiar la trazabilidad quitando comillas y barras invertidas
        final cleanTrazabilidad =
            trazabilidad.replaceAll('"', '').replaceAll('\\', '');

        // Formatear el EPC asegurando que tenga 16 dígitos
        final formattedEPC = cleanTrazabilidad.padLeft(16, '0');

        // Si ya tenemos este EPC, saltamos
        if (epcs.any((e) =>
            e['epc'] == formattedEPC || e['trazabilidad'] == cleanTrazabilidad))
          continue;

        try {
          final response = await http
              .get(Uri.parse("http://172.16.10.31/api/Socket/$formattedEPC"))
              .timeout(Duration(seconds: 10));

          if (response.statusCode == 200 && mounted) {
            final data = Map<String, dynamic>.from(jsonDecode(response.body));
            setState(() {
              epcs.add({
                'epc': formattedEPC,
                'claveProducto': data['claveProducto'] ?? 'N/A',
                'nombreProducto': data['nombreProducto'] ?? 'N/A',
                'pesoNeto': data['pesoNeto']?.toString() ?? 'N/A',
                'piezas': data['piezas']?.toString() ?? 'N/A',
                'trazabilidad': data['trazabilidad'] ?? cleanTrazabilidad,
              });
            });
          }
        } catch (e) {
          print('Error cargando información del EPC $formattedEPC: $e');
          // Si falla la carga, añadimos la información básica
          if (mounted) {
            setState(() {
              epcs.add({
                'epc': formattedEPC,
                'claveProducto': 'N/A',
                'nombreProducto': 'N/A',
                'pesoNeto': 'N/A',
                'piezas': 'N/A',
                'trazabilidad': cleanTrazabilidad,
              });
            });
          }
        }
      } catch (e) {
        print('Error procesando trazabilidad: $e');
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted;
      }
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<void> _stopScanner() async {
    if (!mounted) return;
    try {
      await platform.invokeMethod('stopScan');
      _isScanning = false;
    } catch (e) {
      // Solo registra el error en la consola pero no lo muestra al usuario
      print("Error al detener escaneo (ignorado): $e");

      // Aún así, actualiza el estado interno
      _isScanning = false;

      // No mostramos SnackBar para este error específico
      // _showSnackBar("Error al detener escaneo: $e");  <-- Comenta o elimina esta línea
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

  Future<void> startScanning() async {
    if (!mounted) return;
    try {
      await platform.invokeMethod('startScan');
      _isScanning = true;
      _showSnackBar("Escáner iniciado");
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error al iniciar escaneo: $e");
      }
    }
  }

  Future<void> _processEPC(String epc) async {
    if (epcs.any((e) => e['epc'] == epc)) {
      if (mounted) _showSnackBar("EPC ya escaneado");
      return;
    }

    try {
      final response = await http
          .get(Uri.parse("http://172.16.10.31/api/Socket/$epc"))
          .timeout(Duration(seconds: 10));

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
        _showSnackBar("EPC procesado correctamente");
      } else {
        throw HttpException('Error en la respuesta del servidor');
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error al procesar EPC: $e");
    }
  }

  // Image handling methods
  Future<File?> _optimizeAndSaveImage(File originalImage) async {
    try {
      final directory = await getTemporaryDirectory();
      final targetPath =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final decodedImage =
          await decodeImageFromList(await originalImage.readAsBytes());
      double width = decodedImage.width.toDouble();
      double height = decodedImage.height.toDouble();

      double maxDimension = 2048.0;
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
        quality: 85,
        format: CompressFormat.jpeg,
        minWidth: width.round(),
        minHeight: height.round(),
        keepExif: true,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print("Error optimizing image: $e");
      return null;
    }
  }

  Future<void> captureImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 1536,
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
          _showSnackBar("Foto capturada exitosamente");
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error al capturar imagen: $e");
    }
  }

  Future<void> selectFromGallery() async {
    try {
      final List<XFile> selectedImages = await _imagePicker.pickMultiImage(
        imageQuality: 85,
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
      if (mounted) _showSnackBar("Error al cargar imágenes: $e");
    }
  }

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
      // Primero enviamos los datos principales SIN imágenes
      final request = http.MultipartRequest('POST',
          Uri.parse("http://172.16.10.31/api/RegistrosLogistica/create"));

      final listaEPCs =
          epcs.map((epc) => epc['trazabilidad'].toString()).toList();

      DateTime fecha;
      try {
        fecha = DateTime.parse(fechaController.text);
      } catch (e) {
        fecha = DateTime.now();
      }

      request.fields.addAll({
        'Fecha': fecha.toIso8601String(),
        'NombreOperador': operadorController.text,
        'NumeroLogistica': noLogisticaController.text,
        'Observaciones': observacionesController.text,
        'FechaCreacion': DateTime.now().toIso8601String(),
        'Dispositivo': "ET40",
      });

      for (int i = 0; i < listaEPCs.length; i++) {
        request.fields['ListaEPCs[$i]'] = listaEPCs[i];
      }

      // Enviamos la solicitud principal SIN fotos
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Si los datos principales se subieron correctamente, procedemos con las fotos
        if (images.isNotEmpty) {
          try {
            final numeroLogistica = noLogisticaController.text;
            const int batchSize = 5; // Tamaño del lote: 5 fotos
            int successCount = 0;
            int failedCount = 0;

            // Dividir las imágenes en lotes de 5
            for (int i = 0; i < images.length; i += batchSize) {
              final int end = (i + batchSize < images.length)
                  ? i + batchSize
                  : images.length;
              final batch = images.sublist(i, end);

              if (mounted) {
                _showSnackBar(
                    "Subiendo lote ${(i / batchSize).floor() + 1} de ${(images.length / batchSize).ceil()} (${batch.length} fotos)");
              }

              // Crear solicitud para este lote específico
              final photosRequest = http.MultipartRequest(
                  'POST',
                  Uri.parse(
                      "http://172.16.10.31/api/RegistrosLogistica/AddPhotos/$numeroLogistica"));

              // Añadir solo las fotos de este lote
              for (var image in batch) {
                if (await image.exists()) {
                  final stream = http.ByteStream(image.openRead());
                  final length = await image.length();

                  final multipartFile = http.MultipartFile(
                      'Fotos', stream, length,
                      filename:
                          'lote_${(i / batchSize).floor()}_${DateTime.now().millisecondsSinceEpoch}.jpg');

                  photosRequest.files.add(multipartFile);
                }
              }

              try {
                // Enviar este lote específico con timeout
                final batchResponse =
                    await photosRequest.send().timeout(Duration(seconds: 30));
                final batchResult =
                    await http.Response.fromStream(batchResponse);

                if (batchResponse.statusCode == 200 ||
                    batchResponse.statusCode == 201) {
                  successCount += batch.length;
                  if (mounted) {
                    _showSnackBar(
                        "Progreso: $successCount de ${images.length} fotos subidas");
                  }
                } else {
                  failedCount += batch.length;
                  print(
                      "Error en lote ${(i / batchSize).floor() + 1}: ${batchResult.body}");
                }
              } catch (e) {
                failedCount += batch.length;
                print("Error subiendo lote ${(i / batchSize).floor() + 1}: $e");
                // Continuamos con el siguiente lote en caso de error
              }

              // Pequeña pausa entre lotes para evitar sobrecargar el servidor
              await Future.delayed(Duration(milliseconds: 500));
            }

            if (mounted) {
              if (failedCount > 0) {
                _showSnackBar(
                    "Subida parcial: $successCount de ${images.length} fotos subidas");
              } else {
                _showSnackBar("Todas las fotos subidas correctamente");
              }
            }
          } catch (e) {
            print("Error en la subida por lotes: $e");
            _showSnackBar("Error al subir fotos: $e");
          }
        }

        // Actualizar estado si es necesario
        if (widget.reviewId != null) {
          final putUrl =
              "http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/status";

          final putResponse = await http.put(
            Uri.parse(putUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode("Evidencias Cargadas"), // Enviar solo el string
          );

          if (putResponse.statusCode == 200) {
            print("Estado actualizado correctamente a 'Evidencias Cargadas'");
          } else {
            print("Error al actualizar el estado: ${putResponse.body}");
          }
        }

        await _clearAllData();
        if (mounted) {
          _showSnackBar("Datos subidos exitosamente");
          Navigator.pop(
              context, true); // Regresa a la pantalla anterior con éxito
        }
      } else {
        throw HttpException(
            'Error del servidor: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      _showErrorDialog("Error de conexión", "Detalles: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _clearAllData() async {
    try {
      final directory = await getTemporaryDirectory();
      if (await directory.exists()) {
        await directory.list().forEach((file) async {
          if (file is File) await file.delete();
        });
      }

      if (mounted) {
        setState(() {
          epcs.clear();
          images.clear();
          fechaController.clear();
          operadorController.clear();
          noLogisticaController.clear();
          observacionesController.clear();
          documentacionController.clear();

          // Restablecer checklist de aduana
          aduanaChecklist.forEach((key, value) {
            aduanaChecklist[key] = false;
          });
        });
      }
    } catch (e) {
      print("Error clearing data: $e");
      throw e;
    }
  }

  Future<void> saveEPCsToExcel() async {
    try {
      if (!await requestStoragePermission()) {
        if (!mounted) return;
        _showSnackBar('Permisos de almacenamiento denegados');
        return;
      }

      final excel = xl.Excel.createExcel();
      final xl.Sheet sheet = excel['EPCs'];

      sheet.appendRow([
        xl.TextCellValue('EPC'),
        xl.TextCellValue('Nombre Producto'),
        xl.TextCellValue('Peso Neto'),
        xl.TextCellValue('Clave Producto'),
        xl.TextCellValue('Piezas'),
        xl.TextCellValue('Trazabilidad')
      ]);

      for (var epc in epcs) {
        sheet.appendRow([
          xl.TextCellValue(epc['epc'].toString()),
          xl.TextCellValue(epc['claveProducto'].toString()),
          xl.TextCellValue(epc['nombreProducto'].toString()),
          xl.TextCellValue(epc['pesoNeto'].toString()),
          xl.TextCellValue(epc['piezas'].toString()),
          xl.TextCellValue(epc['trazabilidad'].toString())
        ]);
      }

      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'EPCs_$dateStr.xlsx';
      final filePath = '${dir.path}/$fileName';

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        _showSnackBar('EPCs guardados en: $filePath');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al guardar EPCs: $e');
      }
    }
  }

  Future<void> savePhotosToLocal() async {
    try {
      if (!await requestStoragePermission()) {
        if (!mounted) return;
        _showSnackBar('Permisos de almacenamiento denegados');
        return;
      }

      final dir = Directory('/storage/emulated/0/Download');
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final folderName = 'Photos_$dateStr';
      final saveDir = Directory('${dir.path}/$folderName');

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      int savedCount = 0;
      for (int i = 0; i < images.length; i++) {
        final file = images[i];
        if (await file.exists()) {
          final newPath = '${saveDir.path}/photo_${i + 1}.jpg';
          await file.copy(newPath);
          savedCount++;
        }
      }

      if (mounted) {
        _showSnackBar('$savedCount fotos guardadas en: ${saveDir.path}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al guardar fotos: $e');
      }
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
            padding: EdgeInsets.all(16),
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
                            date.toIso8601String().split('T')[0];
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
                ),
              ],
            ),
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
          content: Text(type == "fotos"
              ? "Esto eliminará todas las fotos capturadas. ¿Desea continuar?"
              : "Esto eliminará todos los EPCs escaneados. ¿Desea continuar?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (type == "fotos") {
                    images.clear();
                    _showSnackBar("Todas las fotos eliminadas");
                  } else {
                    epcs.clear();
                    _showSnackBar("Todos los EPCs eliminados");
                  }
                });
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

  Widget _buildEPCCard(Map<String, dynamic> epc, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  Text("EPC: ${epc['epc']}",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Clave Producto: ${epc['claveProducto']}"),
                  Text("Producto: ${epc['nombreProducto']}"),
                  Text("Peso: ${epc['pesoNeto']} kg"),
                  Text("Piezas: ${epc['piezas']}"),
                  Text("Trazabilidad: ${epc['trazabilidad']}"),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() => epcs.removeAt(index));
                _showSnackBar("EPC eliminado");
              },
            ),
          ],
        ),
      ),
    );
  }

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
                cacheWidth: 240,
                cacheHeight: 240,
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
                  setState(() => images.removeAt(index));
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (epcs.isNotEmpty || images.isNotEmpty) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('¿Descartar cambios?'),
              content: Text(
                  'Hay datos sin guardar. ¿Estás seguro de que quieres salir?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Salir'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          );
          return shouldDiscard ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAduanaReview
              ? 'Revisión de Aduana #${widget.noLogistica}'
              : 'Escanear y Capturar'),
          actions: [
            if (isAduanaReview && widget.reviewStatus != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.reviewStatus!,
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ),
          ],
        ),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopActionBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Si es revisión de aduana, mostrar la información de cliente
                      if (isAduanaReview && widget.cliente != null)
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cliente: ${widget.cliente}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.operador != null)
                                  Text(
                                    'Operador: ${widget.operador}',
                                    style: TextStyle(fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      _buildEPCsList(),
                      _buildImageGallery(),
                    ],
                  ),
                ),
              ),
              _buildBottomActionPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Container(
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
                  onPressed: startScanning,
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
              _buildCounter("Fotos", images.length, Icons.photo_library),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _buildEPCsList() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: epcs.isEmpty
          ? _buildEmptyState("No hay EPCs escaneados", Icons.qr_code)
          : Column(
              children: epcs
                  .asMap()
                  .entries
                  .map((entry) => _buildEPCCard(entry.value, entry.key))
                  .toList(),
            ),
    );
  }

  Widget _buildImageGallery() {
    return SizedBox(
      height: 140,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: images.isEmpty
            ? _buildEmptyState("No hay fotos", Icons.photo_library)
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                cacheExtent: 1000,
                itemBuilder: (context, index) =>
                    _buildImageCard(images[index], index),
              ),
      ),
    );
  }

  Widget _buildBottomActionPanel() {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saveEPCsToExcel,
                  icon: Icon(Icons.file_download),
                  label: Text("Exportar EPCs"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF46707E),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: savePhotosToLocal,
                  icon: Icon(Icons.save_alt),
                  label: Text("Guardar Fotos"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF46707E),
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
              onPressed: isUploading ? null : _showUploadConfirmationModal,
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
                isUploading
                    ? "Subiendo..."
                    : (isAduanaReview ? "Completar Revisión" : "Subir Datos"),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isAduanaReview ? Colors.blue : Color(0xFF4CAF50),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
