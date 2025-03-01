import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'models/epc_info.dart';

class Config {
  static const String url_esp32 =
      'http://172.16.20.125:80'; // url ESP32 corregida
  static const String url_api_rfid = 'http://172.16.10.31'; // url API
}

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
  List<EPCInfo> scannedTags = [];
  String lastScannedTag = "Escáner activado, esperando lectura...";
  bool isLoading = false;
  bool isConnected = false;
  String connectionStatus = "Verificando conexión...";
  Timer? _connectionTimer;
  Timer? _autoReadTimer;
  Timer? _keepAliveTimer;
  bool isAutoReading = false;

  // Variables para registro de conexión
  int _connectionAttempts = 0;
  int _disconnectionCount = 0;
  DateTime? _lastConnectionTime;
  DateTime? _lastDisconnectionTime;
  List<String> _connectionLog = [];

  List<Ubicacion> ubicaciones = [];
  Ubicacion? selectedUbicacion;

  final formKey = GlobalKey<FormState>();
  final dateController = TextEditingController();
  final operatorController = TextEditingController();
  final fileNameController = TextEditingController();
  String selectedFormat = 'Inventario PT';

  final List<String> formatOptions = [
    'Inventario PT',
    'Inventario MP',
    'ExcelGeneral'
  ];

  @override
  void initState() {
    super.initState();
    _logConnection("Iniciando aplicación");
    _checkConnection();
    fetchUbicaciones();
    // Inicializar la fecha actual
    dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Configurar un temporizador para revisar periódicamente la conexión
    _connectionTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkConnection();
    });
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _autoReadTimer?.cancel();
    _keepAliveTimer?.cancel();
    dateController.dispose();
    operatorController.dispose();
    fileNameController.dispose();
    super.dispose();
  }

  // Función de log mejorada
  void _logConnection(String message) {
    String timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    String logMessage = "[$timestamp] $message";
    print(logMessage);

    setState(() {
      _connectionLog.add(logMessage);
      // Mantener solo los últimos 100 mensajes
      if (_connectionLog.length > 100) {
        _connectionLog.removeAt(0);
      }
    });
  }

  // Función para verificar conexión con logging
  Future<void> _checkConnection() async {
    try {
      _logConnection("Verificando conexión con ${Config.url_esp32}/status...");
      final response = await http
          .get(
            Uri.parse('${Config.url_esp32}/status'),
          )
          .timeout(Duration(seconds: 5));

      _logConnection(
          "Respuesta recibida: ${response.statusCode} - ${response.body}");

      bool wasConnected = isConnected;
      setState(() {
        isConnected = response.statusCode == 200;
        connectionStatus =
            isConnected ? "Lector RFID conectado" : "Lector RFID desconectado";
      });

      // Registrar cambios de estado
      if (isConnected && !wasConnected) {
        _lastConnectionTime = DateTime.now();
        _connectionAttempts++;
        _logConnection(
            "🟢 Conexión establecida. Intento #$_connectionAttempts");
      } else if (!isConnected && wasConnected) {
        _lastDisconnectionTime = DateTime.now();
        _disconnectionCount++;
        _logConnection(
            "🔴 Conexión perdida. Desconexión #$_disconnectionCount");

        // Si estaba conectado y se desconectó, intentar reconectar
        _logConnection("Intentando reconexión automática...");
        _conectarYParpadearLED();
      }
    } catch (e) {
      _logConnection("❌ Error en checkConnection: ${e.toString()}");
      if (isConnected) {
        setState(() {
          isConnected = false;
          connectionStatus =
              "Error de conexión: ${e.toString().split('\n')[0]}";
        });

        _lastDisconnectionTime = DateTime.now();
        _disconnectionCount++;
        _logConnection(
            "🔴 Conexión perdida por error. Desconexión #$_disconnectionCount");

        // Intentar reconectar
        _logConnection("Intentando reconexión automática después de error...");
        _conectarYParpadearLED();
      }
    }
  }

  // Función para mantener la conexión activa con pings periódicos
  void _startKeepAlivePing() {
    // Cancelar cualquier timer existente
    _keepAliveTimer?.cancel();

    // Crear un nuevo timer que envía pings cada 5 segundos
    _keepAliveTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (isConnected) {
        try {
          _logConnection("Enviando ping de mantener-vivo...");
          final response = await http
              .get(Uri.parse('${Config.url_esp32}/status'))
              .timeout(Duration(seconds: 3));

          if (response.statusCode == 200) {
            _logConnection("Ping exitoso, conexión mantenida");
          } else {
            _logConnection("❌ Ping falló con código: ${response.statusCode}");
            _checkConnection();
          }
        } catch (e) {
          _logConnection("❌ Error en ping de mantener-vivo: $e");
          _checkConnection();
        }
      } else {
        _logConnection(
            "No se envía ping porque el dispositivo está desconectado");
      }
    });
  }

  Future<void> fetchUbicaciones() async {
    try {
      final response = await http.get(
        Uri.parse("${Config.url_api_rfid}/api/Ubicacion/GetUbicaciones"),
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

  // Función para vincular el dispositivo con logging
  Future<void> _conectarYParpadearLED() async {
    _logConnection("Iniciando conexión con el lector RFID...");
    try {
      final response = await http
          .get(Uri.parse('${Config.url_esp32}/blinkLED'))
          .timeout(Duration(seconds: 10));

      _logConnection(
          "Respuesta de blinkLED: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        // Enviar múltiples parpadeos para confirmar la conexión
        _logConnection(
            "Enviando confirmación de conexión (parpadeos adicionales)");
        await http.get(Uri.parse('${Config.url_esp32}/blinkLED'));
        await http.get(Uri.parse('${Config.url_esp32}/blinkLED'));

        setState(() {
          isConnected = true;
          connectionStatus = "Lector RFID conectado";
        });

        _lastConnectionTime = DateTime.now();
        _connectionAttempts++;
        _logConnection(
            "🟢 Conexión establecida correctamente. Intento #$_connectionAttempts");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Conexión exitosa con el Lector RFID'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Iniciar un ping periódico para mantener la conexión activa
        _startKeepAlivePing();
      } else {
        _logConnection("❌ Error de respuesta: ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al conectar con el ESP32: Código ${response.statusCode}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _logConnection("❌ Excepción al conectar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con el ESP32: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Función para leer EPC con logging mejorado
  Future<void> _leerEPC() async {
    if (!isConnected) {
      if (!isAutoReading) {
        showSnackBar('El lector RFID no está conectado', isError: true);
      }
      return;
    }

    try {
      _logConnection("Leyendo etiqueta RFID...");
      final response = await http
          .get(Uri.parse('${Config.url_esp32}/readTag'))
          .timeout(Duration(seconds: 5));

      _logConnection(
          "Respuesta de lectura: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        String epc = response.body;
        if (!scannedTags.any((tag) => tag.epc == epc)) {
          setState(() {
            lastScannedTag = "Procesando: $epc";
          });
          try {
            _logConnection("Solicitando info para EPC: $epc");
            final epcInfo = await _getEPCInfo(epc);
            _logConnection("Info recibida: ${epcInfo.claveProducto}");

            setState(() {
              scannedTags.add(epcInfo);
              lastScannedTag = "✓ Etiqueta registrada: $epc";
            });

            showSnackBar("Etiqueta registrada correctamente");
            HapticFeedback.mediumImpact();
          } catch (e) {
            _logConnection("❌ Error al obtener información del EPC: $e");
            showSnackBar("Error al obtener información del EPC: $e",
                isError: true);
          }
        }
      }
    } catch (e) {
      _logConnection("❌ Error al leer EPC: $e");
      if (!isAutoReading) {
        showSnackBar('Error al leer EPC: $e', isError: true);
      }

      // Verificar si la conexión se perdió
      if (isConnected) {
        _checkConnection();
      }
    }
  }

  Future<EPCInfo> _getEPCInfo(String epc) async {
    try {
      _logConnection('Obteniendo información para EPC: $epc');
      final response = await http.get(
        Uri.parse('${Config.url_api_rfid}/api/Socket/prueba/$epc'),
      );

      _logConnection('Status Code: ${response.statusCode}');
      _logConnection('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EPCInfo.fromJson(data);
      } else {
        throw Exception(
            'Error al obtener información del EPC: Status ${response.statusCode}');
      }
    } catch (e) {
      _logConnection('Error en _getEPCInfo: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> enviarInformacion() async {
    if (!validarFormulario()) return;

    setState(() {
      isLoading = true;
    });

    try {
      DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(dateController.text);
      String formattedDate = parsedDate.toUtc().toIso8601String();

      final jsonData = {
        "epcs": scannedTags.map((e) => e.epc).toList(),
        "fechaInventario": formattedDate,
        "formatoEtiqueta": selectedFormat,
        "operador": operatorController.text,
        "ubicacion": selectedUbicacion?.claveUbicacion ?? '',
        "nombreArchivo": fileNameController.text,
      };

      _logConnection("Enviando datos al servidor: ${json.encode(jsonData)}");

      final response = await http.post(
        Uri.parse(
            "${Config.url_api_rfid}/api/RfidLabel/generate-excel-from-handheld-save-inventory"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode(jsonData),
      );

      _logConnection(
          "Respuesta del servidor: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        showSnackBar("Información enviada correctamente");
        resetForm();
        Navigator.pop(context);
      } else {
        showSnackBar("Error al enviar datos: ${response.statusCode}",
            isError: true);
      }
    } catch (e) {
      _logConnection("❌ Error al enviar información: $e");
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
      dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      operatorController.clear();
      fileNameController.clear();
      selectedUbicacion = null;
      selectedFormat = 'Inventario PT';
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 10),
              Text('Confirmación'),
            ],
          ),
          content: Text('¿Desea eliminar todos los elementos escaneados?'),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.cancel),
              label: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.delete),
              label: Text('Eliminar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
              primary: Color.fromARGB(255, 20, 71, 71),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
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
        backgroundColor: isError ? Colors.red : Color.fromARGB(255, 20, 71, 71),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(8),
      ),
    );
  }

  void _showEPCDetails(EPCInfo epcInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Color.fromARGB(255, 20, 71, 71)),
              SizedBox(width: 10),
              Text('Detalles de la Tarima'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('ID', epcInfo.id.toString()),
                _buildDetailRow('Área', epcInfo.area),
                _buildDetailRow('Producto', epcInfo.nombreProducto),
                _buildDetailRow('Clave Producto', epcInfo.claveProducto),
                _buildDetailRow('Peso Bruto', '${epcInfo.pesoBruto} kg'),
                _buildDetailRow('Peso Neto', '${epcInfo.pesoNeto} kg'),
                _buildDetailRow('Piezas', epcInfo.piezas.toString()),
                _buildDetailRow('Orden', epcInfo.orden),
                _buildDetailRow('Clave Unidad', epcInfo.claveUnidad),
                _buildDetailRow('Status', epcInfo.status.toString()),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              icon: Icon(Icons.close),
              label: Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 20, 71, 71),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 20, 71, 71),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // Mostrar logs de conexión
  void _mostrarLogsDeConexion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logs de Conexión"),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _connectionLog.length,
            itemBuilder: (context, index) {
              return Text(
                _connectionLog[index],
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _connectionLog[index].contains("❌")
                      ? Colors.red
                      : (_connectionLog[index].contains("🟢")
                          ? Colors.green
                          : Colors.black),
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  void mostrarFormularioEnvio() {
    // Establecer valores iniciales
    dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.edit_document, color: Color.fromARGB(255, 20, 71, 71)),
            SizedBox(width: 10),
            Text("Datos de Lectura"),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: TextFormField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'Fecha',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Campo requerido' : null,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: DropdownButtonFormField<String>(
                      value: selectedFormat,
                      decoration: InputDecoration(
                        labelText: 'Formato',
                        prefixIcon: Icon(Icons.format_list_bulleted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: formatOptions.map((String format) {
                        return DropdownMenuItem(
                          value: format,
                          child: Text(format),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedFormat = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: TextFormField(
                      controller: operatorController,
                      decoration: InputDecoration(
                        labelText: 'Operador',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Campo requerido' : null,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: DropdownButtonFormField<Ubicacion>(
                      value: selectedUbicacion,
                      decoration: InputDecoration(
                        labelText: 'Ubicación',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                      validator: (value) =>
                          value == null ? 'Seleccione una ubicación' : null,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: TextFormField(
                      controller: fileNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del archivo',
                        prefixIcon: Icon(Icons.file_present),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Campo requerido' : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.cancel_outlined, color: Colors.grey),
            label: Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.save),
            label: Text('Guardar'),
            onPressed: enviarInformacion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 20, 71, 71),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Color.fromARGB(255, 20, 71, 71),
        title: Row(
          children: [
            Icon(Icons.nfc, size: 28, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Lector RFID',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _checkConnection,
            tooltip: 'Verificar conexión',
          ),
          IconButton(
            icon: Icon(Icons.report, color: Colors.white),
            onPressed: _mostrarLogsDeConexion,
            tooltip: 'Ver logs de conexión',
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.add_circle_outline),
              tooltip: 'Agregar Registro',
              onPressed: mostrarFormularioEnvio,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Sección de Conexión
            Card(
              margin: EdgeInsets.all(16.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.wifi, color: Colors.white),
                  label: Text(
                    'Vincular dispositivo',
                    style: TextStyle(fontSize: 16),
                  ),
                  onPressed: _conectarYParpadearLED,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 20, 71, 71),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),

            _buildConnectionStatus(),

            // Sección de Botones de Acción
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.delete, color: Colors.white),
                        label: Text(
                          'Limpiar Datos',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: _confirmarBorrarTodo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.nfc, color: Colors.white),
                        label: Text(
                          isAutoReading ? 'Leyendo...' : 'Leer Etiqueta',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: isAutoReading ? null : _leerEPC,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isAutoReading ? Colors.grey : Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contador de EPCs
            Card(
              margin: EdgeInsets.all(16.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total EPCs leídos: ${scannedTags.length}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 20, 71, 71),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lista de EPCs
            Expanded(
              child: Card(
                margin: EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: scannedTags.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.nfc_rounded,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hay lecturas',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(8),
                        itemCount: scannedTags.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                        itemBuilder: (context, index) {
                          final epcInfo = scannedTags[index];
                          return Dismissible(
                            key: Key(epcInfo.epc),
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
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Icon(
                                Icons.nfc,
                                color: Color.fromARGB(255, 20, 71, 71),
                                size: 28,
                              ),
                              title: Text(
                                epcInfo.epc,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(
                                    'Clave Producto: ${epcInfo.claveProducto}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color.fromARGB(255, 20, 71, 71),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.info_outline,
                                      color: Color.fromARGB(255, 20, 71, 71),
                                    ),
                                    onPressed: () => _showEPCDetails(epcInfo),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        scannedTags.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              onTap: () => _showEPCDetails(epcInfo),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
