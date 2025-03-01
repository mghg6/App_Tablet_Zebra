import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebra_scanner_app/AduanalistScreen.dart';
import 'package:zebra_scanner_app/LogisticaListScreen.dart';
import 'package:zebra_scanner_app/logistics_review_screen.dart';
import 'package:zebra_scanner_app/scanandcapture.dart';
import 'package:zebra_scanner_app/dashboard_page.dart';
import 'package:zebra_scanner_app/inventorygenpt.dart';
import 'package:zebra_scanner_app/scanner_page.dart';
import 'package:zebra_scanner_app/manage_pallet.dart';
import 'package:zebra_scanner_app/scannermobileview.dart';
import 'package:zebra_scanner_app/ubicacion_page.dart';
import 'package:zebra_scanner_app/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ZebraScannerApp());
}

class ZebraScannerApp extends StatelessWidget {
  const ZebraScannerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Gestión',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: const Color(0xFF004D40),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF004D40),
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF004D40),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: LoadingScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final PageStorageBucket _bucket = PageStorageBucket();
  static const platform = MethodChannel('zebra_scanner');
  bool _isScannerEnabled = false;

  // Lista de pantallas que requieren el escáner
  final Set<Type> _scannerScreens = {
    ScannerPage,
    ManagePallet,
    UbicacionPage,
    InventoryGenPT,
    ScanAndCapture,
    LogisticaListScreen,
  };

  static final List<MenuOption> _menuOptions = [
    MenuOption(
      title: 'Dashboard',
      icon: Icons.dashboard,
      screen: DashboardPage(),
    ),
    MenuOption(
      title: 'Escáner',
      icon: Icons.qr_code_scanner,
      screen: ScannerPage(),
    ),
    MenuOption(
      title: 'Gestionar Tarima',
      icon: Icons.archive,
      screen: ManagePallet(),
    ),
    MenuOption(
      title: 'Ubicación',
      icon: Icons.map,
      screen: UbicacionPage(),
    ),
    MenuOption(
      title: 'Inventario PT',
      icon: Icons.inventory,
      screen: InventoryGenPT(),
    ),
    MenuOption(
      title: 'Evidencias',
      icon: Icons.photo_library,
      screen: AduanaReviewScreen(),
    ),
    MenuOption(
      title: 'Logísticas',
      icon: Icons.local_shipping,
      screen: LogisticaListScreen(),
    ),
    MenuOption(
      title: 'Revisión de Calidad',
      icon: Icons.assignment_turned_in, // Icono de checklist/revisión
      screen: LogisticsReviewScreen(),
    ),
    MenuOption(
      title: 'Scanner Mobile',
      icon: Icons.nfc, // O podrías usar Icons.qr_code_scanner o Icons.sensors
      screen: ScannerMobileView(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndToggleScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableScanner();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _checkAndToggleScanner();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _disableScanner();
        break;
      default:
        break;
    }
  }

  Future<void> _checkAndToggleScanner() async {
    final currentScreen = _menuOptions[_currentIndex].screen;
    final needsScanner = _scannerScreens.contains(currentScreen.runtimeType);

    if (needsScanner && !_isScannerEnabled) {
      await _enableScanner();
    } else if (!needsScanner && _isScannerEnabled) {
      await _disableScanner();
    }
  }

  Future<void> _enableScanner() async {
    try {
      await platform.invokeMethod('startScan');
      setState(() => _isScannerEnabled = true);
      print('Scanner enabled');
    } catch (e) {
      print('Error enabling scanner: $e');
    }
  }

  Future<void> _disableScanner() async {
    if (!_isScannerEnabled) return;

    try {
      await platform.invokeMethod('stopScan');
      setState(() => _isScannerEnabled = false);
      print('Scanner disabled');
    } catch (e) {
      print('Error disabling scanner: $e');
    }
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: const Color(0xFF00695C),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Image.network(
          'https://darsis.us/bioflex/wp-content/uploads/2023/05/logo_b.png',
          height: 100,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Error al cargar imagen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawerItem(MenuOption option, int index) {
    final bool isSelected = _currentIndex == index;
    final bool usesScanner =
        _scannerScreens.contains(option.screen.runtimeType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
      ),
      child: ListTile(
        leading: Stack(
          children: [
            Icon(
              option.icon,
              color: Colors.white,
            ),
            if (usesScanner)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          option.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () async {
          setState(() => _currentIndex = index);
          await _checkAndToggleScanner();
          Navigator.of(context).pop();
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_menuOptions[_currentIndex].title),
        actions: [
          if (_isScannerEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Icon(
                Icons.sensors,
                color: Colors.amber,
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF00695C),
          child: Column(
            children: [
              _buildDrawerHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _menuOptions.length,
                  itemBuilder: (context, index) => _buildDrawerItem(
                    _menuOptions[index],
                    index,
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    if (_isScannerEnabled)
                      Row(
                        children: [
                          Icon(
                            Icons.sensors,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Scanner Activo',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: PageStorage(
        bucket: _bucket,
        child: _menuOptions[_currentIndex].screen,
      ),
    );
  }
}

class MenuOption {
  final String title;
  final IconData icon;
  final Widget screen;

  const MenuOption({
    required this.title,
    required this.icon,
    required this.screen,
  });
}
