import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DeleteTag extends StatefulWidget {
  @override
  _DeleteTagState createState() => _DeleteTagState();
}

class _DeleteTagState extends State<DeleteTag> {
  static const platform = MethodChannel('zebra_scanner');
  String scannedCode = 'Escanee una etiqueta';
  bool isProcessing = false;
  final String _password = "demo123"; // Contraseña definida para la demo

  void _enableScanner() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "barcodeScanned") {
        String rawCode = call.arguments.toString().split(RegExp(r'[ -]')).first;
        String formattedCode = rawCode.padLeft(16, '0');
        setState(() {
          scannedCode = formattedCode;
        });
        _showSnackBar("Etiqueta escaneada: $formattedCode");
      }
    });
  }

  void _disableScanner() {
    platform.setMethodCallHandler(null); // Limpia el controlador
  }

  Future<void> startScanning() async {
    try {
      await platform.invokeMethod('startScan');
    } on PlatformException catch (e) {
      setState(() {
        scannedCode = "Error: ${e.message}";
      });
    }
  }

  Future<void> deleteTag(String code) async {
    setState(() {
      isProcessing = true;
    });

    final url = Uri.parse("http://172.16.10.31/api/Tags/Delete/$code");
    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        _showSnackBar("Etiqueta eliminada exitosamente.");
        setState(() {
          scannedCode = "Escanee una etiqueta";
        });
      } else {
        _showSnackBar("Error al eliminar la etiqueta. Intente nuevamente.");
      }
    } catch (e) {
      _showSnackBar("Error en la conexión al servidor.");
    } finally {
      setState(() {
        isProcessing = false;
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

  Future<void> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmación Requerida'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Ingrese la contraseña para proceder:'),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Contraseña',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Confirmar'),
              onPressed: () {
                if (passwordController.text == _password) {
                  Navigator.of(context).pop();
                  deleteTag(scannedCode);
                } else {
                  _showSnackBar("Contraseña incorrecta.");
                }
              },
            ),
          ],
        );
      },
    );
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFE8F1F2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Color(0xFF46707E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                scannedCode,
                style: TextStyle(fontSize: 20, color: Color(0xFF46707E)),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: startScanning,
              icon: Icon(Icons.qr_code_scanner, color: Colors.white),
              label: Text(
                "Iniciar Escaneo",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF46707E),
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: scannedCode == "Escanee una etiqueta" || isProcessing
                  ? null
                  : _showPasswordDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: isProcessing ? Colors.grey : Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: isProcessing
                  ? CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : Text(
                      "Eliminar Etiqueta",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
