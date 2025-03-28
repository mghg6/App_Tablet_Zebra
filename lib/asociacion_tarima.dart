import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Modelo para Operador
class Operador {
  final int id;
  final String rfidOperador;
  final String nombreOperador;

  Operador({
    required this.id,
    required this.rfidOperador,
    required this.nombreOperador,
  });

  factory Operador.fromJson(Map<String, dynamic> json) {
    return Operador(
      id: json['id'],
      rfidOperador: json['rfiD_Operador'] ?? json['rfidOperador'],
      nombreOperador: json['nombreOperador'],
    );
  }
}

// Modelo para asociación reciente
class AsociacionReciente {
  final String qr;
  final String operador;
  final String timestamp;

  AsociacionReciente({
    required this.qr,
    required this.operador,
    required this.timestamp,
  });
}

class AsociacionTarima extends StatefulWidget {
  @override
  _AsociacionTarimaState createState() => _AsociacionTarimaState();
}

class _AsociacionTarimaState extends State<AsociacionTarima>
    with WidgetsBindingObserver {
  // Constante para el canal de comunicación con el scanner Zebra
  static const platform = MethodChannel('zebra_scanner');

  // Estado de la aplicación
  List<Operador> operadores = [];
  String? selectedOperatorId;
  String? selectedOperatorName;
  bool isLoading = false;
  bool isLoadingOperators = true;
  bool isScanning = false;
  bool isProcessing = false;
  String? scannerResult;
  List<AsociacionReciente> recentAssociations = [];

  // Controlador para entrada manual
  final TextEditingController manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchOperadores();
    // Iniciar el scanner después de un breve retraso para asegurar que la UI esté lista
    Future.delayed(Duration(milliseconds: 500), () {
      enableScanner();
    });
  }

  @override
  void dispose() {
    stopScanner();
    WidgetsBinding.instance.removeObserver(this);
    manualInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!isScanning) enableScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        stopScanner();
        break;
      default:
        break;
    }
  }

  // Obtener la lista de operadores del API
  Future<void> fetchOperadores() async {
    setState(() {
      isLoadingOperators = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse("http://172.16.10.31/api/OperadoresRFID"),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          operadores = data.map((json) => Operador.fromJson(json)).toList();
          isLoadingOperators = false;
        });
      } else {
        throw Exception('Error en la respuesta: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoadingOperators = false;
      });
      showSnackBar("Error al obtener operadores: $e", isError: true);
    }
  }

  // Habilitar el scanner Zebra
  Future<void> enableScanner() async {
    if (isScanning) return;

    try {
      // Configurar el handler para recibir los escaneos
      platform.setMethodCallHandler((call) async {
        if (call.method == "barcodeScanned" && !isProcessing) {
          setState(() {
            isProcessing = true;
          });

          // Procesar el código escaneado
          try {
            final rawCode = call.arguments.toString();
            // Extraer y formatear el código como es necesario
            final formattedCode =
                rawCode.split(RegExp(r'[ -]')).first.padLeft(16, '0');
            await processScannedQR(formattedCode);
          } finally {
            setState(() {
              isProcessing = false;
            });
          }
        }
        return null;
      });

      // Iniciar el scanner
      await platform.invokeMethod('startScan');
      setState(() {
        isScanning = true;
      });
      showSnackBar("Escáner iniciado");
    } catch (e) {
      showSnackBar("Error al iniciar el escáner: $e", isError: true);
    }
  }

  // Detener el scanner
  Future<void> stopScanner() async {
    if (!isScanning) return;

    try {
      await platform.invokeMethod('stopScan');
      setState(() {
        isScanning = false;
      });
    } catch (e) {
      print("Error al detener el escáner: $e");
    }
  }

  // Procesar el QR escaneado o ingresado manualmente
  Future<void> processScannedQR(String qrText) async {
    if (selectedOperatorId == null) {
      showSnackBar("Selecciona un operador antes de escanear", isError: true);
      return;
    }

    setState(() {
      scannerResult = qrText;
      isLoading = true;
    });

    try {
      // Preparar los datos para la solicitud
      final payload = {
        "PalletEpc": "000$qrText", // Agregar prefijo "000"
        "OperatorEpc": selectedOperatorId,
      };

      // Enviar la solicitud al API
      final response = await http
          .post(
            Uri.parse("http://172.16.10.31:81/api/Test/simulate-association"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Añadir a historial reciente
        final operatorName = operadores
            .firstWhere((op) => op.rfidOperador == selectedOperatorId,
                orElse: () => Operador(
                    id: 0, rfidOperador: "", nombreOperador: "Desconocido"))
            .nombreOperador;

        setState(() {
          recentAssociations.insert(
            0,
            AsociacionReciente(
              qr: qrText,
              operador: operatorName,
              timestamp: DateFormat('HH:mm:ss').format(DateTime.now()),
            ),
          );

          // Mantener solo las 5 asociaciones más recientes
          if (recentAssociations.length > 5) {
            recentAssociations = recentAssociations.sublist(0, 5);
          }
        });

        showSnackBar("¡Asociación exitosa!");
        // Vibración para feedback táctil
        HapticFeedback.mediumImpact();
      } else {
        throw Exception("Error en la asociación: ${response.statusCode}");
      }
    } catch (e) {
      showSnackBar("Error de asociación: $e", isError: true);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Mostrar SnackBar con mensajes
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
        backgroundColor: isError ? Colors.red : Color(0xFF153E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(8),
      ),
    );
  }

  // Mostrar diálogo de confirmación
  Future<bool> showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF153E3E),
            ),
            child: Text("Confirmar"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF153E3E), Color(0xFF0d2b2b)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Panel izquierdo - Operadores y escáner
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Tarjeta de selección de operador
                          _buildOperatorCard(),
                          SizedBox(height: 16),
                          // Tarjeta de escáner
                          _buildScannerCard(),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    // Panel derecho - Historial de asociaciones
                    Expanded(
                      flex: 1,
                      child: _buildRecentAssociationsCard(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para la tarjeta de selección de operador
  Widget _buildOperatorCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            isLoadingOperators
                ? Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFe1a21b),
                    ),
                  )
                : Column(
                    children: [
                      // Dropdown para seleccionar operador
                      Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Color(0xFFe1a21b), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedOperatorId,
                          decoration: InputDecoration(
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                            border: InputBorder.none,
                            hintText: "Seleccionar operador",
                          ),
                          items: operadores.map((operador) {
                            return DropdownMenuItem(
                              value: operador.rfidOperador,
                              child: Text(operador.nombreOperador),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedOperatorId = value;
                              selectedOperatorName = operadores
                                  .firstWhere((op) => op.rfidOperador == value,
                                      orElse: () => Operador(
                                          id: 0,
                                          rfidOperador: "",
                                          nombreOperador: ""))
                                  .nombreOperador;
                            });
                          },
                        ),
                      ),
                      // Mostrar el operador seleccionado
                      if (selectedOperatorName != null)
                        Container(
                          margin: EdgeInsets.only(top: 16),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Operador seleccionado: $selectedOperatorName",
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
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

  // Widget para la tarjeta del escáner
  Widget _buildScannerCard() {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Color(0xFF153E3E)),
                  SizedBox(width: 8),
                  Text(
                    "Escanear Tarima",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF153E3E),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Estado del escáner
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isScanning ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isScanning
                        ? Colors.green.shade200
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isScanning
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isScanning ? Icons.sensors : Icons.sensors_off,
                        color: isScanning ? Colors.green : Colors.grey,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isScanning ? "Escáner activo" : "Escáner inactivo",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isScanning
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            isScanning
                                ? "Escanea el código QR de una tarima"
                                : "El escáner está desactivado",
                            style: TextStyle(
                              color: isScanning
                                  ? Colors.green.shade600
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isScanning
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: isScanning
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                      onPressed: () {
                        if (isScanning) {
                          stopScanner();
                        } else {
                          enableScanner();
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Entrada manual
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manualInputController,
                      decoration: InputDecoration(
                        labelText: "O ingresa el código manualmente",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () {
                            if (manualInputController.text.isNotEmpty) {
                              processScannedQR(manualInputController.text);
                              manualInputController.clear();
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          processScannedQR(value);
                          manualInputController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Resultado del escáner
              if (scannerResult != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Último código escaneado:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.shade200,
                          ),
                        ),
                        child: Text(
                          scannerResult!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Spacer(),
              // Indicador de carga
              if (isLoading)
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFe1a21b),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Procesando...",
                        style: TextStyle(
                          color: Color(0xFFe1a21b),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para la tarjeta de asociaciones recientes
  Widget _buildRecentAssociationsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Color(0xFF153E3E)),
                SizedBox(width: 8),
                Text(
                  "Asociaciones Recientes",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF153E3E),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: recentAssociations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No hay asociaciones recientes",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: recentAssociations.length,
                      itemBuilder: (context, index) {
                        final association = recentAssociations[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    association.timestamp,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                association.operador,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  association.qr,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
