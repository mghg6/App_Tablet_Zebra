import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MaterialSeparationWidget extends StatefulWidget {
  final GlobalKey<MaterialSeparationWidgetState> materialKey;
  final Map<String, dynamic> registro;

  const MaterialSeparationWidget({
    super.key,
    required this.registro,
    required this.materialKey,
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

  // Nuevo mapa para mantener todos los EPCs
  static final Map<String, Set<String>> _allEpcsMap = {};

  // Variables de estado locales
  late Set<String> epcsEscaneados;
  late List<Map<String, dynamic>> tarimasEscaneadas;
  double cantidadProgramada = 0;
  double cantidadPendiente = 0;
  late double cantidadSeparada;
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _epcController = TextEditingController();

  // Getter para la clave única del producto
  String get _productKey =>
      '${widget.registro['itemCode']}_${widget.registro['pedido']}';

  // Método estático para obtener todos los EPCs
  static List<String> getAllEpcs() {
    return _allEpcsMap.values.expand((epcs) => epcs).toList();
  }

  static void resetAllData() {
    _globalEpcsEscaneados.clear();
    _globalTarimasEscaneadas.clear();
    _globalCantidadesSeparadas.clear();
    _allEpcsMap.clear();
  }

  // Agregar este método de instancia para resetear el estado local
  void resetLocalData() {
    setState(() {
      epcsEscaneados.clear();
      tarimasEscaneadas.clear();
      cantidadSeparada = 0;
      cantidadPendiente = cantidadProgramada;
      _epcController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _inicializarCantidades();
    _inicializarDatosGuardados();
  }

  void _inicializarDatosGuardados() {
    final productKey = _productKey;

    // Inicializar las estructuras globales si no existen
    _globalEpcsEscaneados[productKey] ??= {};
    _globalTarimasEscaneadas[productKey] ??= [];
    _globalCantidadesSeparadas[productKey] ??= 0.0;
    _allEpcsMap[productKey] ??= {};

    // Asignar valores locales desde el almacenamiento global
    setState(() {
      epcsEscaneados = _globalEpcsEscaneados[productKey]!;
      tarimasEscaneadas = List.from(_globalTarimasEscaneadas[productKey]!);
      cantidadSeparada = _globalCantidadesSeparadas[productKey]!;
      cantidadPendiente = cantidadProgramada - cantidadSeparada;
    });
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
          final productKey = _productKey;
          _globalEpcsEscaneados[productKey]!.add(epc);
          _globalTarimasEscaneadas[productKey] = List.from(tarimasEscaneadas);
          _globalCantidadesSeparadas[productKey] = cantidadSeparada;
          _allEpcsMap[productKey]!.add(epc);
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
                          setState(() {
                            // Actualizar estado local
                            cantidadPendiente += tarima['cantidadUsada'];
                            cantidadSeparada -= tarima['cantidadUsada'];
                            epcsEscaneados.remove(tarima['epc']);
                            tarimasEscaneadas.removeAt(index);

                            // Actualizar almacenamiento global
                            final productKey = _productKey;
                            _globalEpcsEscaneados[productKey]!
                                .remove(tarima['epc']);
                            _globalTarimasEscaneadas[productKey] =
                                List.from(tarimasEscaneadas);
                            _globalCantidadesSeparadas[productKey] =
                                cantidadSeparada;
                            _allEpcsMap[productKey]!.remove(tarima['epc']);
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
