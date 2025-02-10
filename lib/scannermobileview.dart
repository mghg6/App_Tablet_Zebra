import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

class ScannerMobileView extends StatefulWidget {
  @override
  _ScannerMobileViewState createState() => _ScannerMobileViewState();
}

class _ScannerMobileViewState extends State<ScannerMobileView> {
  List<Map<String, dynamic>> scannedTags = [];
  String lastScannedTag = "Escáner activado, esperando lectura...";
  bool isLoading = false;
  bool isConnected = false;
  String connectionStatus = "Verificando conexión...";
  Timer? _connectionTimer;
  Timer? _autoReadTimer;
  bool isAutoReading = false;

  List<Ubicacion> ubicaciones = [];
  Ubicacion? selectedUbicacion;

  final formKey = GlobalKey<FormState>();
  final dateController = TextEditingController();
  final operatorController = TextEditingController();
  final fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkConnection();
    fetchUbicaciones();
    _connectionTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkConnection();
    });
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _autoReadTimer?.cancel();
    dateController.dispose();
    operatorController.dispose();
    fileNameController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://172.16.20.172:80/status'),
          )
          .timeout(Duration(seconds: 5));

      setState(() {
        isConnected = response.statusCode == 200;
        connectionStatus =
            isConnected ? "Lector RFID conectado" : "Lector RFID desconectado";
      });
    } catch (e) {
      setState(() {
        isConnected = false;
        connectionStatus = "Error de conexión: ${e.toString().split('\n')[0]}";
      });
    }
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

  void _toggleAutoRead() {
    setState(() {
      isAutoReading = !isAutoReading;
      if (isAutoReading) {
        _autoReadTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
          _leerEPC();
        });
      } else {
        _autoReadTimer?.cancel();
      }
    });
  }

  Future<void> _leerEPC() async {
    if (!isConnected) {
      if (!isAutoReading) {
        showSnackBar('El lector RFID no está conectado', isError: true);
      }
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('http://172.16.20.172:80/readTag}'),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        String epc = response.body;
        if (!scannedTags.any((tag) => tag['trazabilidad'] == epc)) {
          setState(() {
            lastScannedTag = "Procesando: $epc";
          });
          await fetchPalletData(epc);
        }
      }
    } catch (e) {
      if (!isAutoReading) {
        showSnackBar('Error al leer EPC: $e', isError: true);
      }
    }
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

  Future<void> enviarInformacion() async {
    if (!validarFormulario()) return;

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
          "fechaInventario": dateController.text,
          "formatoEtiqueta": "Inventario",
          "operador": operatorController.text,
          "ubicacion": selectedUbicacion?.claveUbicacion,
          "nombreArchivo": fileNameController.text,
        }),
      );

      if (response.statusCode == 200) {
        showSnackBar("Información enviada correctamente");
        resetForm();
        Navigator.pop(context);
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

  void resetForm() {
    setState(() {
      scannedTags.clear();
      dateController.clear();
      operatorController.clear();
      fileNameController.clear();
      selectedUbicacion = null;
      lastScannedTag = "Escáner activado, esperando lectura...";
    });
  }

  bool validarFormulario() {
    if (scannedTags.isEmpty) {
      showSnackBar("No hay etiquetas escaneadas", isError: true);
      return false;
    }
    if (dateController.text.isEmpty ||
        operatorController.text.isEmpty ||
        selectedUbicacion == null ||
        fileNameController.text.isEmpty) {
      showSnackBar("Complete todos los campos del formulario", isError: true);
      return false;
    }
    return true;
  }

  Future<void> _confirmarBorrarTodo() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmación'),
          content: Text('¿Desea eliminar todos los elementos escaneados?'),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Borrar todo'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      setState(() {
        scannedTags.clear();
        lastScannedTag = "Escáner activado, esperando lectura...";
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
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

    if (picked != null) {
      setState(() {
        dateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
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
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDateField(),
                SizedBox(height: 16),
                _buildFormField(
                  controller: operatorController,
                  label: "Operador",
                  icon: Icons.person,
                ),
                SizedBox(height: 16),
                _buildUbicacionDropdown(),
                SizedBox(height: 16),
                _buildFormField(
                  controller: fileNameController,
                  label: "Nombre del Archivo",
                  icon: Icons.file_present,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: enviarInformacion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: _buildFormField(
          controller: dateController,
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

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            color: isConnected ? Colors.green : Colors.red,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              connectionStatus,
              style: TextStyle(
                color:
                    isConnected ? Colors.green.shade900 : Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isConnected)
            Switch(
              value: isAutoReading,
              onChanged: (value) => _toggleAutoRead(),
              activeColor: Colors.green,
            ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        title: Text('Scanner Mobile'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _checkConnection,
            tooltip: 'Verificar conexión',
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: mostrarFormularioEnvio,
            tooltip: 'Enviar datos',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.delete),
                    label: Text('Limpiar'),
                    onPressed: _confirmarBorrarTodo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.nfc),
                    label: Text(isAutoReading ? 'Leyendo...' : 'Leer EPC'),
                    onPressed: isAutoReading ? null : _leerEPC,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isAutoReading ? Colors.grey : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.sensors,
                          color: Colors.teal,
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
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.teal))
                  : scannedTags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.nfc,
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
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: scannedTags.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1),
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
                                margin: EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 8),
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
                                      colors: [
                                        Colors.white,
                                        Colors.teal.shade50
                                      ],
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
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                    ),
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
