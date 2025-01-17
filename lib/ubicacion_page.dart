import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UbicacionPage extends StatefulWidget {
  @override
  _UbicacionPageState createState() => _UbicacionPageState();
}

class _UbicacionPageState extends State<UbicacionPage>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('zebra_scanner');
  String scannedCode = 'Lector activado, esperando escaneo...';
  String? selectedRack;
  String? selectedSide;
  String? selectedLevel;
  String? selectedPosition;
  String traceability = '';
  bool isScanning = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(Duration(milliseconds: 500), () {
      enableScannerAndStart();
    });
  }

  @override
  void dispose() {
    stopScanning();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  void showSnackBar(BuildContext context, String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(8),
      ),
    );
  }

  Future<void> enableScannerAndStart() async {
    if (!isScanning) {
      await enableScanner();
      await startScanning();
      setState(() {
        isScanning = true;
      });
    }
  }

  Future<void> enableScanner() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        await processScannedCode(call.arguments.toString());
      }
    });
  }

  Future<void> processScannedCode(String rawCode) async {
    String processedCode = rawCode.split(RegExp(r'[ -]')).first;
    processedCode = processedCode.length == 13
        ? processedCode
        : processedCode.padLeft(13, '0');

    setState(() {
      traceability = processedCode;
      scannedCode = "Trazabilidad: $processedCode";
    });

    showSnackBar(context, "Código escaneado correctamente",
        color: Colors.green);

    HapticFeedback.mediumImpact();
  }

  Future<void> startScanning() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      setState(() {
        scannedCode = "Error al iniciar el escáner: ${e.message}";
      });
      showSnackBar(context, "Error al iniciar el escáner", color: Colors.red);
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
          color: Colors.orange);
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
        showSnackBar(context, "Ubicación asignada: $location",
            color: Colors.green);
        setState(() {
          resetSelection();
        });
      } else {
        showSnackBar(
            context, "Error: ${response.reasonPhrase ?? 'Error desconocido'}",
            color: Colors.red);
      }
    } catch (e) {
      showSnackBar(context, "Error de conexión: $e", color: Colors.red);
    }
  }

  void resetSelection() {
    setState(() {
      selectedRack = null;
      selectedSide = null;
      selectedLevel = null;
      selectedPosition = null;
      traceability = '';
      scannedCode = 'Lector activado, esperando escaneo...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: resetSelection,
            tooltip: 'Reiniciar selección',
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
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScannerStatus(),
                  SizedBox(height: 20),
                  _buildSelectionSection(),
                  if (selectedPosition != null) _buildConfirmationSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerStatus() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: traceability.isEmpty ? Colors.grey.shade300 : Colors.teal,
            width: 2,
          ),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              traceability.isEmpty ? Colors.grey.shade50 : Colors.teal.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    isScanning
                        ? Icons.qr_code_scanner
                        : Icons.qr_code_scanner_outlined,
                    color: isScanning ? Colors.teal : Colors.grey,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado del Escáner',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        isScanning ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          color: isScanning ? Colors.green : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    color: Colors.teal,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scannedCode,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
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

  Widget _buildSelectionSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Rack", Icons.grid_view),
            SizedBox(height: 8),
            _buildRackSelection(),
            if (selectedRack != null) ...[
              SizedBox(height: 20),
              _buildSectionTitle("Lado", Icons.border_all),
              SizedBox(height: 8),
              _buildSideSelection(),
            ],
            if (selectedSide != null) ...[
              SizedBox(height: 20),
              _buildSectionTitle("Nivel", Icons.layers),
              SizedBox(height: 8),
              _buildLevelSelection(),
            ],
            if (selectedLevel != null) ...[
              SizedBox(height: 20),
              _buildSectionTitle("Posición", Icons.place),
              SizedBox(height: 8),
              _buildPositionSelection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal, size: 24),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRackSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rackConfig
          .map((rack) => rack['rack'] as String)
          .toSet()
          .map((rack) => _buildSelectionChip(
                label: rack,
                isSelected: selectedRack == rack,
                onSelected: (isSelected) {
                  setState(() {
                    selectedRack = isSelected ? rack : null;
                    selectedSide = null;
                    selectedLevel = null;
                    selectedPosition = null;
                  });
                },
              ))
          .toList(),
    );
  }

  Widget _buildSideSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: getAvailableSides()
          .map((side) => _buildSelectionChip(
                label: side,
                isSelected: selectedSide == side,
                onSelected: (isSelected) {
                  setState(() {
                    selectedSide = isSelected ? side : null;
                    selectedLevel = null;
                    selectedPosition = null;
                  });
                },
              ))
          .toList(),
    );
  }

  Widget _buildLevelSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        getAvailableLevels(),
        (index) => _buildSelectionChip(
          label: "Nivel ${index + 1}",
          isSelected: selectedLevel == "Nivel ${index + 1}",
          onSelected: (isSelected) {
            setState(() {
              selectedLevel = isSelected ? "Nivel ${index + 1}" : null;
              selectedPosition = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPositionSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        getAvailablePositions(),
        (index) => _buildSelectionChip(
          label: "Posición ${index + 1}",
          isSelected: selectedPosition == "Posición ${index + 1}",
          onSelected: (isSelected) {
            setState(() {
              selectedPosition = isSelected ? "Posición ${index + 1}" : null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSelectionChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: Colors.teal,
      backgroundColor: Colors.grey.shade100,
      checkmarkColor: Colors.white,
      elevation: 2,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.teal : Colors.grey.shade300,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildConfirmationSection() {
    String location =
        "$selectedRack-$selectedSide-NV${selectedLevel?.replaceFirst("Nivel ", "")}-P${selectedPosition?.replaceFirst("Posición ", "")}";

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Confirmación", Icons.check_circle_outline),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow("Ubicación:", location),
                  SizedBox(height: 8),
                  _buildInfoRow("Trazabilidad:",
                      traceability.isEmpty ? "No escaneada" : traceability),
                ],
              ),
            ),
            SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => sendLocation(),
                    icon: Icon(Icons.save),
                    label: Text("Confirmar Ubicación"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: resetSelection,
                    icon: Icon(Icons.refresh),
                    label: Text("Reiniciar Selección"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
            fontSize: 16,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
