import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelo para Ubicación
class Ubicacion {
  final int idUbicacion;
  final String claveUbicacion;

  Ubicacion({
    required this.idUbicacion,
    required this.claveUbicacion,
  });

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      idUbicacion: json['idUbicacion'],
      claveUbicacion: json['claveUbicacion'],
    );
  }
}

class InventoryGenPT extends StatefulWidget {
  @override
  _InventoryGenPTState createState() => _InventoryGenPTState();
}

class _InventoryGenPTState extends State<InventoryGenPT>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('zebra_scanner');
  List<Map<String, dynamic>> scannedTags = [];
  String lastScannedTag = "Escáner activado, esperando lectura...";
  bool isLoading = false;
  bool isScanning = false;

  // Variables para ubicaciones
  List<Ubicacion> ubicaciones = [];
  Ubicacion? selectedUbicacion;

  // Controlador para entrada manual
  final TextEditingController manualInputController = TextEditingController();

  // Controladores para el formulario
  final TextEditingController fechaInventarioController =
      TextEditingController();
  final TextEditingController operadorController = TextEditingController();
  final TextEditingController nombreArchivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchUbicaciones();
    Future.delayed(Duration(milliseconds: 500), () {
      enableScannerAndStart();
    });
  }

  @override
  void dispose() {
    stopScanning();
    WidgetsBinding.instance.removeObserver(this);
    manualInputController.dispose();
    fechaInventarioController.dispose();
    operadorController.dispose();
    nombreArchivoController.dispose();
    super.dispose();
  }

  Future<void> fetchUbicaciones() async {
    try {
      final response = await http.get(
        Uri.parse("http://172.16.10.31/api/Ubicacion/GetUbicaciones"),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          ubicaciones = data.map((json) => Ubicacion.fromJson(json)).toList();
        });
      }
    } catch (e) {
      showSnackBar("Error al cargar ubicaciones: $e", isError: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        enableScannerAndStart();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        stopScanning();
        break;
      default:
        break;
    }
  }

  Future<void> enableScannerAndStart() async {
    if (!isScanning) {
      await _enableScanner();
      await _startScanning();
      setState(() {
        isScanning = true;
      });
    }
  }

  Future<void> _enableScanner() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        await processScannedTag(call.arguments.toString());
      }
    });
  }

  Future<void> _startScanning() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      showSnackBar("Error al iniciar el escáner: ${e.message}", isError: true);
    }
  }

  Future<void> stopScanning() async {
    if (isScanning) {
      try {
        await platform.invokeMethod('stopScan');
        setState(() {
          isScanning = false;
        });
      } catch (e) {
        print('Error al detener el escáner: $e');
      }
    }
  }

  Future<void> processScannedTag(String rawCode) async {
    String extractedCode = rawCode.split(RegExp(r'[ -]')).first;
    String formattedCode = extractedCode.length < 16
        ? extractedCode.padLeft(16, '0')
        : extractedCode;

    if (scannedTags.any((tag) => tag['trazabilidad'] == formattedCode)) {
      showSnackBar("Etiqueta duplicada: $formattedCode", isError: true);
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      lastScannedTag = "Procesando: $formattedCode";
    });

    await fetchPalletData(formattedCode);
  }

  Future<void> fetchPalletData(String epc) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse("http://172.16.10.31/api/Socket/$epc"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          final tagInfo = {
            'claveProducto': data['claveProducto'] ?? 'N/A',
            'pesoNeto': data['pesoNeto'] ?? 'N/A',
            'piezas': data['piezas'] ?? 'N/A',
            'trazabilidad': epc,
          };

          setState(() {
            scannedTags.add(tagInfo);
            lastScannedTag = "✓ Etiqueta registrada: $epc";
          });

          showSnackBar("Etiqueta registrada correctamente");
          HapticFeedback.mediumImpact();
        }
      } else {
        showSnackBar("Error: Tarima no encontrada", isError: true);
      }
    } catch (e) {
      showSnackBar("Error de conexión: $e", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _confirmarBorrarTodo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text("Confirmar borrado"),
          ],
        ),
        content: Text(
            "¿Está seguro que desea borrar todos los elementos escaneados?"),
        actions: [
          TextButton(
            child: Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text("Borrar todo"),
            onPressed: () {
              setState(() {
                scannedTags.clear();
                lastScannedTag = "Escáner activado, esperando lectura...";
              });
              Navigator.pop(context);
              showSnackBar("Se han borrado todos los elementos");
            },
          ),
        ],
      ),
    );
  }

  Future<void> enviarInformacion() async {
    if (!validarFormulario()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            "http://172.16.10.31/api/RfidLabel/generate-excel-from-handheld-save-inventory"),
        headers: {
          "Content-Type": "application/json",
          "accept": "*/*",
        },
        body: jsonEncode({
          "epcs":
              scannedTags.map((tag) => tag['trazabilidad'] as String).toList(),
          "fechaInventario": fechaInventarioController.text,
          "formatoEtiqueta": "Inventario",
          "operador": operadorController.text,
          "ubicacion": selectedUbicacion?.claveUbicacion,
          "nombreArchivo": nombreArchivoController.text,
        }),
      );

      if (response.statusCode == 200) {
        showSnackBar("Información enviada correctamente");
        resetForm();
      } else {
        showSnackBar("Error al enviar datos: ${response.statusCode}",
            isError: true);
      }
    } catch (e) {
      showSnackBar("Error de conexión: $e", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  bool validarFormulario() {
    if (scannedTags.isEmpty) {
      showSnackBar("No hay etiquetas escaneadas", isError: true);
      return false;
    }
    if (fechaInventarioController.text.isEmpty ||
        operadorController.text.isEmpty ||
        selectedUbicacion == null ||
        nombreArchivoController.text.isEmpty) {
      showSnackBar("Complete todos los campos del formulario", isError: true);
      return false;
    }
    return true;
  }

  void resetForm() {
    setState(() {
      scannedTags.clear();
      fechaInventarioController.clear();
      operadorController.clear();
      nombreArchivoController.clear();
      selectedUbicacion = null;
      lastScannedTag = "Escáner activado, esperando lectura...";
    });
  }

  void mostrarFormularioEnvio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory, color: Colors.teal),
            SizedBox(width: 8),
            Text("Enviar Inventario"),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDateField(),
                SizedBox(height: 16),
                _buildFormField(
                  controller: operadorController,
                  label: "Operador",
                  icon: Icons.person,
                ),
                SizedBox(height: 16),
                _buildUbicacionDropdown(),
                SizedBox(height: 16),
                _buildFormField(
                  controller: nombreArchivoController,
                  label: "Nombre del Archivo",
                  icon: Icons.file_present,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.cancel_outlined),
            label: Text("Cancelar"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.send),
            label: Text("Enviar"),
            onPressed: () {
              Navigator.of(context).pop();
              enviarInformacion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.teal,
                ),
              ),
              child: child!,
            );
          },
        );

        if (date != null) {
          setState(() {
            fechaInventarioController.text =
                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          });
        }
      },
      child: AbsorbPointer(
        child: _buildFormField(
          controller: fechaInventarioController,
          label: "Fecha de Inventario",
          icon: Icons.calendar_today,
          hint: "YYYY-MM-DD",
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.teal),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUbicacionDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<Ubicacion>(
        value: selectedUbicacion,
        decoration: InputDecoration(
          labelText: "Ubicación",
          prefixIcon: Icon(Icons.place, color: Colors.teal),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: ubicaciones.map((ubicacion) {
          return DropdownMenuItem(
            value: ubicacion,
            child: Text(ubicacion.claveUbicacion),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedUbicacion = value;
          });
        },
      ),
    );
  }

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        title: Text("Inventario"),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: () => _confirmarBorrarTodo(),
            tooltip: 'Borrar todo',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: resetForm,
            tooltip: 'Reiniciar formulario',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            _buildManualInput(),
            _buildScannerStatus(),
            Expanded(
              child: _buildProductList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: mostrarFormularioEnvio,
        backgroundColor: Colors.teal,
        icon: Icon(Icons.send),
        label: Text("Enviar"),
      ),
    );
  }

  Widget _buildManualInput() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: manualInputController,
                decoration: InputDecoration(
                  labelText: "Ingresar código manualmente",
                  hintText: "Escriba el código de trazabilidad",
                  prefixIcon: Icon(Icons.edit, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    processScannedTag(value);
                    manualInputController.clear();
                  }
                },
              ),
            ),
            SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                if (manualInputController.text.isNotEmpty) {
                  processScannedTag(manualInputController.text);
                  manualInputController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerStatus() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isScanning
                        ? Colors.teal.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isScanning ? Icons.sensors : Icons.sensors_off,
                    color: isScanning ? Colors.teal : Colors.grey,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastScannedTag,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Total etiquetas: ${scannedTags.length}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
        ),
      );
    }

    if (scannedTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              "No hay etiquetas escaneadas",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Escanee una etiqueta o ingrese manualmente",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: scannedTags.length,
      itemBuilder: (context, index) {
        final tag = scannedTags[index];
        return Dismissible(
          key: Key(tag['trazabilidad']),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 30,
            ),
          ),
          onDismissed: (direction) {
            setState(() {
              scannedTags.removeAt(index);
            });
            showSnackBar(
              "Etiqueta eliminada",
              isError: false,
            );
          },
          child: Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.teal.shade100,
                width: 1,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.teal.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  "Clave: ${tag['claveProducto']}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                subtitle: Text(
                  "Peso: ${tag['pesoNeto']} kg",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          icon: Icons.numbers,
                          label: "Piezas",
                          value: "${tag['piezas']}",
                        ),
                        SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.qr_code,
                          label: "Trazabilidad",
                          value: "${tag['trazabilidad']}",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        SizedBox(width: 8),
        Text(
          "$label:",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }
}
