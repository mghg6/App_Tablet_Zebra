// material_separation.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MaterialSeparationWidget extends StatefulWidget {
  final Map<String, dynamic> registro;

  const MaterialSeparationWidget({
    Key? key,
    required this.registro,
  }) : super(key: key);

  @override
  _MaterialSeparationWidgetState createState() =>
      _MaterialSeparationWidgetState();
}

class _MaterialSeparationWidgetState extends State<MaterialSeparationWidget> {
  Set<String> epcsEscaneados = {};
  List<Map<String, dynamic>> tarimasEscaneadas = [];
  double cantidadProgramada = 0;
  double cantidadPendiente = 0;
  double cantidadSeparada = 0;
  bool isLoading = false;
  String? errorMessage;
  TextEditingController _epcController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inicializarCantidades();
  }

  @override
  void dispose() {
    _epcController.dispose();
    super.dispose();
  }

  void _inicializarCantidades() {
    cantidadProgramada =
        double.tryParse(widget.registro['programado']?.toString() ?? '0') ?? 0;
    cantidadPendiente = cantidadProgramada;
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
      print('EPC formateado: $epc'); // Debug

      final response = await http
          .get(Uri.parse('http://172.16.10.31/api/Socket/$epc'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Datos recibidos del EPC: $data'); // Debug
        print('Datos de la logística: ${widget.registro}'); // Debug

        // Obtener y normalizar los códigos
        String claveProductoTarima =
            (data['claveProducto'] ?? '').toString().trim().toUpperCase();
        String itemCodeLogistica =
            (widget.registro['itemCode'] ?? '').toString().trim().toUpperCase();

        print(
            'Comparando - claveProducto Tarima: $claveProductoTarima con itemCode Logística: $itemCodeLogistica'); // Debug

        // Comparar claveProducto del EPC con itemCode de la logística
        if (claveProductoTarima == itemCodeLogistica) {
          print('Coincidencia encontrada. Procesando tarima...'); // Debug
          _procesarTarima(epc, data);
        } else {
          print('No coinciden los códigos'); // Debug
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
      print('Procesando tarima - Unidad logística: $unidadLogistica');

      // Calcular el límite máximo permitido (120% de la cantidad programada)
      double limiteSuperior = cantidadProgramada * 1.20;

      if (unidadLogistica == 'KGM') {
        cantidadTarima =
            double.tryParse(tarimaData['pesoNeto']?.toString() ?? '0') ?? 0;
        print('Usando peso neto: $cantidadTarima kg');
      } else if (['H87', 'XBX', 'MIL'].contains(unidadLogistica)) {
        cantidadTarima =
            double.tryParse(tarimaData['piezas']?.toString() ?? '0') ?? 0;
        print('Usando piezas: $cantidadTarima pzs');
      }

      if (cantidadTarima <= 0) {
        _mostrarError('Cantidad inválida en la tarima');
        return;
      }

      // Verificar si al agregar la nueva tarima excedería el límite del 120%
      double cantidadTotalPotencial = cantidadSeparada + cantidadTarima;

      if (cantidadTotalPotencial <= limiteSuperior) {
        setState(() {
          epcsEscaneados.add(epc);
          tarimasEscaneadas.add({
            ...tarimaData,
            'epc': epc,
            'cantidadUsada': cantidadTarima,
            'fechaEscaneo': DateTime.now(),
          });
          cantidadPendiente -= cantidadTarima;
          cantidadSeparada += cantidadTarima;
        });
        _epcController.clear();

        // Mostrar advertencia si supera el 100% pero está dentro del 120%
        if (cantidadTotalPotencial > cantidadProgramada) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _epcController,
              decoration: InputDecoration(
                labelText: 'Escanear QR/Código de Tarima',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                helperText:
                    'El código se completará automáticamente a 16 dígitos',
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  // Obtener solo los números hasta el primer espacio
                  String processedValue =
                      value.split(' ')[0].replaceAll(RegExp(r'[^0-9]'), '');

                  // Si el valor procesado es diferente al valor actual, actualizar el controller
                  if (processedValue != value) {
                    _epcController.value = TextEditingValue(
                      text: processedValue,
                      selection: TextSelection.collapsed(
                          offset: processedValue.length),
                    );
                  }

                  // Verificar si ya alcanzó los 16 dígitos
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
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
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
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: cantidadSeparada / cantidadProgramada,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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
      constraints: BoxConstraints(maxHeight: 250),
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
            margin: EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                'EPC: ${tarima['epc']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lote: ${tarima['trazabilidad'] ?? 'N/A'}'),
                  Text('Cantidad: $cantidad'),
                ],
              ),
              trailing: Container(
                width: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        tarima['fechaEscaneo'].toString().split('.')[0],
                        style: TextStyle(
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
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            cantidadPendiente += tarima['cantidadUsada'];
                            cantidadSeparada -= tarima['cantidadUsada'];
                            epcsEscaneados.remove(tarima['epc']);
                            tarimasEscaneadas.removeAt(index);
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
      margin: EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Separación de Material',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
              ],
            ),
            SizedBox(height: 16),
            _buildEscanerInput(),
            SizedBox(height: 16),
            _buildContador(),
            SizedBox(height: 16),
            Text(
              'Tarimas Escaneadas:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _buildListaTarimas(),
          ],
        ),
      ),
    );
  }
}
