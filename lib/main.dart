import 'package:flutter/material.dart';
import 'package:zebra_scanner_app/scanandcapture.dart';
import 'dashboard_page.dart';
import 'delete_tag.dart';
import 'inventorygenpt.dart';
import 'scanner_page.dart';
import 'product_detail.dart';
import 'settings_page.dart';
import 'manage_pallet.dart';
import 'ubicacion_page.dart'; // Importa la nueva vista de Ubicación
import 'loading_screen.dart'; // Importa la vista de carga

void main() {
  runApp(ZebraScannerApp());
}

class ZebraScannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Arial',
      ),
      home: LoadingScreen(), // Establece LoadingScreen como pantalla inicial
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardPage(),
    ScannerPage(),
    ProductDetail(),
    ManagePallet(),
    UbicacionPage(),
    DeleteTag(),
    InventoryGenPT(), // Nueva vista
    ScanAndCapture(),
    SettingsPage(),
  ];

  final List<String> _menuOptions = [
    'Dashboard',
    'Escáner',
    'Detalles',
    'Gestionar Tarima',
    'Ubicación',
    'Eliminar Etiqueta',
    'Inventario PT',
    'Evidencias',
    'Ajustes',
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _menuOptions[_currentIndex],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Texto blanco para contraste
          ),
        ),
        backgroundColor: Color(0xFF004D40), // Verde azulado oscuro
        elevation: 4,
        centerTitle: true, // Centra el título
        iconTheme: IconThemeData(color: Colors.white), // Íconos blancos
      ),
      drawer: Drawer(
        child: Container(
          color: Color(0xFF00695C), // Fondo verde más claro
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF00695C), // Fondo del Drawer
                ),
                child: Center(
                  child: Image.network(
                    'https://darsis.us/bioflex/wp-content/uploads/2023/05/logo_b.png',
                    height: 100, // Ajusta la altura según sea necesario
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              ..._menuOptions.asMap().entries.map((entry) {
                int index = entry.key;
                String option = entry.value;

                return ListTile(
                  leading: Icon(
                    index == 0
                        ? Icons.dashboard
                        : index == 1
                            ? Icons.qr_code_scanner
                            : index == 2
                                ? Icons.info
                                : index == 3
                                    ? Icons.archive
                                    : index == 4
                                        ? Icons.map // Ícono para "Ubicación"
                                        : index == 5
                                            ? Icons.delete_forever
                                            : index == 6
                                                ? Icons.inventory
                                                : index == 7
                                                    ? Icons.photo_library
                                                    : Icons.settings,
                    color: Colors.white,
                  ),
                  title: Text(
                    option,
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                    Navigator.of(context).pop(); // Cierra el Drawer
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
      body: _screens[_currentIndex],
    );
  }
}
