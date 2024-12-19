import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UbicacionPage extends StatefulWidget {
  @override
  _UbicacionPageState createState() => _UbicacionPageState();
}

class _UbicacionPageState extends State<UbicacionPage> {
  static const platform = MethodChannel('zebra_scanner');
  String scannedCode = 'Escanee un código de barras';
  String? selectedRack;
  String? selectedSide;
  String? selectedLevel;
  String? selectedPosition;
  String traceability = '';

  final rackConfig = [
    {"rack": "RA", "side": "L1", "levels": 8, "positionsPerLevel": 18},
    {"rack": "RB", "side": "L1", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RB", "side": "L2", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RC", "side": "L1", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RC", "side": "L2", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RD", "side": "L1", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RD", "side": "L2", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RE", "side": "L1", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RE", "side": "L2", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RF", "side": "L1", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RF", "side": "L2", "levels": 4, "positionsPerLevel": 20},
    {"rack": "RG", "side": "L1", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RG", "side": "L2", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RH", "side": "L1", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RH", "side": "L2", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RI", "side": "L1", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RI", "side": "L2", "levels": 3, "positionsPerLevel": 20},
    {"rack": "RJ", "side": "L1", "levels": 8, "positionsPerLevel": 14},
    {"rack": "RK", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RK", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RL", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RL", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RM", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RM", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RN", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RN", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RO", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RO", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RP", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RP", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RQ", "side": "L1", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RQ", "side": "L2", "levels": 8, "positionsPerLevel": 10},
    {"rack": "RR", "side": "L1", "levels": 6, "positionsPerLevel": 10},
    {"rack": "RR", "side": "L2", "levels": 6, "positionsPerLevel": 10},
    {"rack": "RS", "side": "L1", "levels": 6, "positionsPerLevel": 10},
    {"rack": "RT", "side": "L1", "levels": 8, "positionsPerLevel": 24},
    {"rack": "RU", "side": "L1", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RU", "side": "L2", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RV", "side": "L1", "levels": 6, "positionsPerLevel": 24},
    {"rack": "RW", "side": "L1", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RW", "side": "L2", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RX", "side": "L1", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RX", "side": "L2", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RV", "side": "L2", "levels": 6, "positionsPerLevel": 24},
    {"rack": "RY", "side": "L1", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RY", "side": "L2", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RZ", "side": "L1", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RZ", "side": "L2", "levels": 7, "positionsPerLevel": 24},
    {"rack": "RAA", "side": "L1", "levels": 8, "positionsPerLevel": 24},
    {"rack": "RAA", "side": "L2", "levels": 8, "positionsPerLevel": 24},
    {"rack": "RAB", "side": "L1", "levels": 8, "positionsPerLevel": 24},
    {"rack": "RAB", "side": "L2", "levels": 8, "positionsPerLevel": 24},
    {"rack": "RAC", "side": "L1", "levels": 8, "positionsPerLevel": 24},
  ];

  void showSnackBar(BuildContext context, String message, {Color? color}) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: color ?? Colors.teal,
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  List<String> getAvailableSides() {
    return rackConfig
        .where((rack) => rack['rack'] == selectedRack)
        .map((rack) => rack['side'] as String)
        .toList();
  }

  int getAvailableLevels() {
    final rack = rackConfig.firstWhere(
      (r) => r['rack'] == selectedRack && r['side'] == selectedSide,
      orElse: () => {"levels": 0},
    );
    return rack['levels'] as int;
  }

  int getAvailablePositions() {
    final rack = rackConfig.firstWhere(
      (r) => r['rack'] == selectedRack && r['side'] == selectedSide,
      orElse: () => {"positionsPerLevel": 0},
    );
    return rack['positionsPerLevel'] as int;
  }

  Future<void> sendLocation() async {
    if (selectedRack == null ||
        selectedSide == null ||
        selectedLevel == null ||
        selectedPosition == null ||
        traceability.isEmpty) {
      showSnackBar(context, "Por favor, completa todos los campos",
          color: Colors.red);
      return;
    }

    final location =
        "$selectedRack-$selectedSide-NV${selectedLevel?.replaceFirst("Nivel ", "")}-P${selectedPosition?.replaceFirst("Posición ", "")}";

    try {
      final response = await http.put(
        Uri.parse(
            "http://172.16.10.31/api/Ubicacion/AssignLocation/$traceability"),
        headers: {"Content-Type": "application/json"},
        body: '"$location"',
      );

      if (response.statusCode == 200) {
        final message = "Ubicación asignada correctamente: $location";
        showSnackBar(context, message);
        setState(() {
          resetSelection();
        });
      } else {
        final error = response.reasonPhrase ?? "Error desconocido";
        showSnackBar(context, "Error: $error", color: Colors.red);
      }
    } catch (e) {
      showSnackBar(context, "Error: $e", color: Colors.red);
    }
  }

  void resetSelection() {
    setState(() {
      selectedRack = null;
      selectedSide = null;
      selectedLevel = null;
      selectedPosition = null;
      traceability = '';
      scannedCode = 'Escanee un código de barras';
    });
  }

  void enableScanner() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        String rawCode = call.arguments.toString().split(RegExp(r'[ -]')).first;
        if (rawCode.length == 13) {
          traceability = rawCode;
        } else {
          traceability = rawCode.padLeft(13, '0');
        }
        setState(() {
          scannedCode = "Trazabilidad Escaneada: $traceability";
        });
        showSnackBar(context, "Trazabilidad escaneada correctamente");
      }
    });
  }

  void startScanning() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      setState(() {
        scannedCode = "Error: ${e.message}";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    enableScanner();
  }

  @override
  void dispose() {
    platform.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selección de Rack
              Text("Selecciona un Rack:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: rackConfig
                    .map((rack) => rack['rack'] as String)
                    .toSet()
                    .map((rack) {
                  return ChoiceChip(
                    label: Text(rack),
                    selected: selectedRack == rack,
                    onSelected: (isSelected) {
                      setState(() {
                        selectedRack = isSelected ? rack : null;
                        selectedSide = null;
                        selectedLevel = null;
                        selectedPosition = null;
                      });
                    },
                  );
                }).toList(),
              ),
              // Selección de Lado
              if (selectedRack != null) ...[
                SizedBox(height: 16),
                Text("Selecciona el Lado:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 10,
                  children: getAvailableSides().map((side) {
                    return ChoiceChip(
                      label: Text(side),
                      selected: selectedSide == side,
                      onSelected: (isSelected) {
                        setState(() {
                          selectedSide = isSelected ? side : null;
                          selectedLevel = null;
                          selectedPosition = null;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              // Selección de Nivel
              if (selectedSide != null) ...[
                SizedBox(height: 16),
                Text("Selecciona el Nivel:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 10,
                  children: List.generate(getAvailableLevels(), (index) {
                    String level = "Nivel ${index + 1}";
                    return ChoiceChip(
                      label: Text(level),
                      selected: selectedLevel == level,
                      onSelected: (isSelected) {
                        setState(() {
                          selectedLevel = isSelected ? level : null;
                          selectedPosition = null;
                        });
                      },
                    );
                  }),
                ),
              ],
              // Selección de Posición
              if (selectedLevel != null) ...[
                SizedBox(height: 16),
                Text("Selecciona la Posición:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 10,
                  children: List.generate(getAvailablePositions(), (index) {
                    String position = "Posición ${index + 1}";
                    return ChoiceChip(
                      label: Text(position),
                      selected: selectedPosition == position,
                      onSelected: (isSelected) {
                        setState(() {
                          selectedPosition = isSelected ? position : null;
                        });
                      },
                    );
                  }),
                ),
              ],
              // Confirmación y Escaneo
              if (selectedPosition != null) ...[
                SizedBox(height: 16),
                Text("Trazabilidad:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(scannedCode, style: TextStyle(fontSize: 16)),
                ),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: startScanning,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text("Iniciar Escaneo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: sendLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text("Confirmar",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
