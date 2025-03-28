import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MaterialSeparationWidget extends StatefulWidget {
  final GlobalKey<MaterialSeparationWidgetState> materialKey;
  final Map<String, dynamic> registro;
  // Agregar número de logística como parámetro
  final dynamic noLogistica;

  const MaterialSeparationWidget({
    super.key,
    required this.registro,
    required this.materialKey,
    required this.noLogistica, // Nuevo parámetro obligatorio
  });

  @override
  MaterialSeparationWidgetState createState() =>
      MaterialSeparationWidgetState();
}

class MaterialSeparationWidgetState extends State<MaterialSeparationWidget> {
  // Almacenamiento estático global para mantener datos entre instancias
  static final Map<String, Set<String>> _globalEpcsEscaneados = {};
  static final Map<String, List<Map<String, dynamic>>>
      _globalTarimasEscaneadas = {};
  static final Map<String, double> _globalCantidadesSeparadas = {};

  // Mantener un mapa de EPCs por logística
  static final Map<String, Map<String, Set<String>>>
      _epcsEscaneadosPorLogistica = {};

  // Variables de estado locales
  late Set<String> epcsEscaneados;
  late List<Map<String, dynamic>> tarimasEscaneadas;
  double cantidadProgramada = 0;
  double cantidadPendiente = 0;
  late double cantidadSeparada;
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _epcController = TextEditingController();

  // Getter para la clave única del producto que incluye la logística
  String get _productKey {
    return '${widget.noLogistica}_${widget.registro['itemCode']}_${widget.registro['pedido']}';
  }

  // Getter para la clave de logística
  String get _logisticaKey {
    return widget.noLogistica.toString();
  }

  // Método estático para obtener todos los EPCs de una logística específica
  static List<String> getEpcsByLogistica(String logisticaId) {
    Set<String> result = {};

    // Verificar si hay datos para esa logística
    if (_epcsEscaneadosPorLogistica.containsKey(logisticaId)) {
      // Recorrer todos los productos de esa logística y acumular sus EPCs
      _epcsEscaneadosPorLogistica[logisticaId]!.values.forEach((epcs) {
        result.addAll(epcs);
      });
    }

    return result.toList();
  }

  // Método estático para obtener TODOS los EPCs (para depuración)
  static List<String> getAllEpcs() {
    Set<String> result = {};

    // Recorrer todas las logísticas
    _epcsEscaneadosPorLogistica.values.forEach((logisticaMap) {
      // Para cada logística, recorrer todos sus productos
      logisticaMap.values.forEach((epcs) {
        result.addAll(epcs);
      });
    });

    return result.toList();
  }

  // Mantiene compatibilidad con el código original que llamaba a getAllEpcs sin parámetros
  // pero devuelve solo los EPCs de la logística especificada
  static List<String> getEpcsByLogisticaId(String logisticaId) {
    return getEpcsByLogistica(logisticaId);
  }

  // Método estático mejorado para limpiar todos los datos globales
  static void resetAllData() {
    print("🧹 Iniciando resetAllData() global");
    print(
        "📊 Estado antes del reset: ${_epcsEscaneadosPorLogistica.length} logísticas en caché");

    int totalEpcsAntes = 0;
    _epcsEscaneadosPorLogistica.forEach((logistica, productos) {
      productos.forEach((producto, epcs) {
        totalEpcsAntes += epcs.length;
      });
    });
    print("📊 Total de EPCs antes del reset: $totalEpcsAntes");

    _globalEpcsEscaneados.clear();
    _globalTarimasEscaneadas.clear();
    _globalCantidadesSeparadas.clear();
    _epcsEscaneadosPorLogistica.clear();

    print(
        "✅ resetAllData() completado, todos los datos globales han sido limpiados");
    print(
        "📊 Estado después del reset: ${_epcsEscaneadosPorLogistica.length} logísticas, ${getAllEpcs().length} EPCs totales");
  }

  // Método para limpiar datos de una logística específica
  static void resetLogisticaData(String logisticaId) {
    print("🧹 Iniciando resetLogisticaData() para logística $logisticaId");

    if (_epcsEscaneadosPorLogistica.containsKey(logisticaId)) {
      int epcsCount = 0;
      _epcsEscaneadosPorLogistica[logisticaId]!.forEach((producto, epcs) {
        epcsCount += epcs.length;
      });

      print("📊 EPCs antes del reset para logística $logisticaId: $epcsCount");

      // Eliminar todos los registros para esta logística
      _epcsEscaneadosPorLogistica.remove(logisticaId);

      // También limpiar los datos antiguos que correspondan a esta logística
      List<String> keysToRemove = [];
      _globalEpcsEscaneados.keys.forEach((key) {
        if (key.startsWith("${logisticaId}_")) {
          keysToRemove.add(key);
        }
      });

      for (String key in keysToRemove) {
        _globalEpcsEscaneados.remove(key);
        _globalTarimasEscaneadas.remove(key);
        _globalCantidadesSeparadas.remove(key);
      }

      print("✅ resetLogisticaData() completado para logística $logisticaId");
      print(
          "📊 EPCs después del reset: ${getEpcsByLogistica(logisticaId).length}");
    } else {
      print("⚠️ No se encontraron datos para la logística $logisticaId");
    }
  }

  // Método de instancia para resetear el estado local de un widget
  void resetLocalData() {
    if (mounted) {
      final productKey = _productKey;
      final logisticaKey = _logisticaKey;

      print(
          "🔄 Iniciando resetLocalData() para producto $productKey en logística $logisticaKey");
      print(
          "📊 Estado antes del reset: ${epcsEscaneados.length} EPCs, $cantidadSeparada separados");

      setState(() {
        epcsEscaneados.clear();
        tarimasEscaneadas.clear();
        cantidadSeparada = 0;
        cantidadPendiente = cantidadProgramada;
        _epcController.clear();
      });

      // También limpiar los datos en el mapa global
      if (_epcsEscaneadosPorLogistica.containsKey(logisticaKey) &&
          _epcsEscaneadosPorLogistica[logisticaKey]!.containsKey(productKey)) {
        _epcsEscaneadosPorLogistica[logisticaKey]![productKey]!.clear();
      }

      print(
          "✅ resetLocalData() completado para $productKey en logística $logisticaKey");
      print(
          "📊 Estado después del reset: ${epcsEscaneados.length} EPCs, $cantidadSeparada separados");
    } else {
      print("⚠️ resetLocalData() llamado cuando el widget no está montado");
    }
  }

  @override
  void initState() {
    super.initState();
    _inicializarCantidades();
    _inicializarDatosGuardados();
  }

  void _inicializarDatosGuardados() {
    final productKey = _productKey;
    final logisticaKey = _logisticaKey;

    // Inicializar las estructuras globales si no existen
    _globalEpcsEscaneados[productKey] ??= {};
    _globalTarimasEscaneadas[productKey] ??= [];
    _globalCantidadesSeparadas[productKey] ??= 0.0;

    // Inicializar el mapa de EPCs por logística
    _epcsEscaneadosPorLogistica[logisticaKey] ??= {};
    _epcsEscaneadosPorLogistica[logisticaKey]![productKey] ??= {};

    // Asignar valores locales desde el almacenamiento global
    setState(() {
      epcsEscaneados = _globalEpcsEscaneados[productKey]!;
      tarimasEscaneadas = List.from(_globalTarimasEscaneadas[productKey]!);
      cantidadSeparada = _globalCantidadesSeparadas[productKey]!;
      cantidadPendiente = cantidadProgramada - cantidadSeparada;
    });

    print(
        "🔄 Inicializado widget para producto $productKey en logística $logisticaKey");
    print(
        "📊 EPCs cargados: ${epcsEscaneados.length}, cantidad separada: $cantidadSeparada");
  }

  void _inicializarCantidades() {
    cantidadProgramada =
        double.tryParse(widget.registro['programado']?.toString() ?? '0') ?? 0;
    cantidadPendiente = cantidadProgramada;
  }

  Set<String> getScannedEpcs() {
    return epcsEscaneados;
  }

  String _formatearQRaEPC(String codigoQR) {
    String codigo = codigoQR.trim();
    if (codigo.length == 16) return codigo;
    return codigo.padLeft(16, '0');
  }

  Future<void> _fetchTarimaData(String codigo) async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      String epc = _formatearQRaEPC(codigo);
      print('EPC formateado: $epc');

      final response = await http
          .get(Uri.parse('http://172.16.10.31/api/Socket/$epc'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Datos recibidos del EPC: $data');
        print('Datos de la logística: ${widget.registro}');

        String claveProductoTarima =
            (data['claveProducto'] ?? '').toString().trim().toUpperCase();
        String itemCodeLogistica =
            (widget.registro['itemCode'] ?? '').toString().trim().toUpperCase();

        if (claveProductoTarima == itemCodeLogistica) {
          _procesarTarima(epc, data);
        } else {
          _mostrarError(
              'El producto de la tarima ($claveProductoTarima) no coincide con el solicitado ($itemCodeLogistica)');
        }
      } else {
        _mostrarError('Tarima no encontrada (${response.statusCode})');
      }
    } catch (e) {
      _mostrarError('Error en la lectura: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _procesarTarima(String epc, Map<String, dynamic> tarimaData) {
    final productKey = _productKey;
    final logisticaKey = _logisticaKey;

    // Verificar si este EPC ya fue escaneado en CUALQUIER logística
    bool epcUsadoGlobalmente = false;

    for (var logisticaMap in _epcsEscaneadosPorLogistica.values) {
      for (var productoEpcs in logisticaMap.values) {
        if (productoEpcs.contains(epc)) {
          epcUsadoGlobalmente = true;
          break;
        }
      }
      if (epcUsadoGlobalmente) break;
    }

    if (epcUsadoGlobalmente) {
      _mostrarError('Este EPC ya fue escaneado en otra logística');
      return;
    }

    if (!epcsEscaneados.contains(epc)) {
      final unidadLogistica = widget.registro['unidad'];
      double cantidadTarima = 0;

      double limiteSuperior = cantidadProgramada * 1.20;

      if (unidadLogistica == 'KGM') {
        cantidadTarima =
            double.tryParse(tarimaData['pesoNeto']?.toString() ?? '0') ?? 0;
      } else if (['H87', 'XBX', 'MIL'].contains(unidadLogistica)) {
        cantidadTarima =
            double.tryParse(tarimaData['piezas']?.toString() ?? '0') ?? 0;
      }

      if (cantidadTarima <= 0) {
        _mostrarError('Cantidad inválida en la tarima');
        return;
      }

      double cantidadTotalPotencial = cantidadSeparada + cantidadTarima;

      if (cantidadTotalPotencial <= limiteSuperior) {
        setState(() {
          // Actualizar estado local
          epcsEscaneados.add(epc);
          tarimasEscaneadas.add({
            ...tarimaData,
            'epc': epc,
            'cantidadUsada': cantidadTarima,
            'fechaEscaneo': DateTime.now(),
          });
          cantidadPendiente -= cantidadTarima;
          cantidadSeparada += cantidadTarima;

          // Actualizar almacenamiento global
          _globalEpcsEscaneados[productKey]!.add(epc);
          _globalTarimasEscaneadas[productKey] = List.from(tarimasEscaneadas);
          _globalCantidadesSeparadas[productKey] = cantidadSeparada;

          // Actualizar el mapa de EPCs por logística
          _epcsEscaneadosPorLogistica[logisticaKey]![productKey]!.add(epc);

          print(
              "➕ EPC $epc agregado al producto $productKey en logística $logisticaKey");
          print("📊 Total EPCs para este producto: ${epcsEscaneados.length}");
          print(
              "📊 Total EPCs para esta logística: ${getEpcsByLogistica(logisticaKey).length}");
        });

        _epcController.clear();

        if (cantidadTotalPotencial > cantidadProgramada) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Advertencia: Se ha superado la cantidad programada pero está dentro del límite permitido del 20%'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        _mostrarError(
            'La cantidad total (${cantidadTotalPotencial.toStringAsFixed(2)}) excede el límite permitido del 20% (${limiteSuperior.toStringAsFixed(2)})');
      }
    } else {
      _mostrarError('Esta tarima ya fue escaneada');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEscanerInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _epcController,
              decoration: const InputDecoration(
                labelText: 'Escanear QR/Código de Tarima',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                helperText:
                    'El código se completará automáticamente a 16 dígitos',
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  String processedValue =
                      value.split(' ')[0].replaceAll(RegExp(r'[^0-9]'), '');

                  if (processedValue != value) {
                    _epcController.value = TextEditingValue(
                      text: processedValue,
                      selection: TextSelection.collapsed(
                          offset: processedValue.length),
                    );
                  }

                  if (processedValue.length >= 16) {
                    _fetchTarimaData(processedValue);
                  }
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  String processedValue =
                      value.split(' ')[0].replaceAll(RegExp(r'[^0-9]'), '');
                  if (processedValue.length < 16) {
                    _fetchTarimaData(processedValue);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // Implementación futura del scanner
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContador() {
    final unidad = widget.registro['unidad'];
    final unidadTexto = unidad == 'KGM' ? 'kg' : 'pzs';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Programado:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    '${cantidadProgramada.toStringAsFixed(2)} $unidadTexto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Pendiente:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    '${cantidadPendiente.toStringAsFixed(2)} $unidadTexto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Separado:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    '${cantidadSeparada.toStringAsFixed(2)} $unidadTexto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: cantidadSeparada / cantidadProgramada,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildListaTarimas() {
    if (tarimasEscaneadas.isEmpty) {
      return Center(
        child: Text(
          'No hay tarimas escaneadas',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: tarimasEscaneadas.length,
        itemBuilder: (context, index) {
          final tarima = tarimasEscaneadas[index];
          final unidad = widget.registro['unidad'];
          final cantidad = unidad == 'KGM'
              ? '${tarima['cantidadUsada'].toStringAsFixed(2)} kg'
              : '${tarima['cantidadUsada'].toStringAsFixed(0)} pzs';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                'EPC: ${tarima['epc']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lote: ${tarima['trazabilidad'] ?? 'N/A'}'),
                  Text('Cantidad: $cantidad'),
                ],
              ),
              trailing: SizedBox(
                width: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        tarima['fechaEscaneo'].toString().split('.')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      width: 30,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          final productKey = _productKey;
                          final logisticaKey = _logisticaKey;

                          setState(() {
                            // Actualizar estado local
                            cantidadPendiente += tarima['cantidadUsada'];
                            cantidadSeparada -= tarima['cantidadUsada'];
                            epcsEscaneados.remove(tarima['epc']);
                            tarimasEscaneadas.removeAt(index);

                            // Actualizar almacenamiento global
                            _globalEpcsEscaneados[productKey]!
                                .remove(tarima['epc']);
                            _globalTarimasEscaneadas[productKey] =
                                List.from(tarimasEscaneadas);
                            _globalCantidadesSeparadas[productKey] =
                                cantidadSeparada;

                            // Actualizar el mapa de EPCs por logística
                            _epcsEscaneadosPorLogistica[logisticaKey]![
                                    productKey]!
                                .remove(tarima['epc']);

                            print(
                                "➖ EPC eliminado: ${tarima['epc']} para $productKey en logística $logisticaKey");
                            print(
                                "📊 Total EPCs para este producto: ${epcsEscaneados.length}");
                            print(
                                "📊 Total EPCs para esta logística: ${getEpcsByLogistica(logisticaKey).length}");
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Separación de Material',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
              ],
            ),
            const SizedBox(height: 16),
            _buildEscanerInput(),
            const SizedBox(height: 16),
            _buildContador(),
            const SizedBox(height: 16),
            const Text(
              'Tarimas Escaneadas:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildListaTarimas(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _epcController.dispose();
    super.dispose();
  }
}
