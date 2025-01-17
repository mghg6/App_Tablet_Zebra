import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:zebra_scanner_app/widgets/material_separation.dart';

class LogisticaDetailScreen extends StatefulWidget {
  final int noLogistica;

  const LogisticaDetailScreen({Key? key, required this.noLogistica})
      : super(key: key);

  @override
  _LogisticaDetailScreenState createState() => _LogisticaDetailScreenState();
}

class _LogisticaDetailScreenState extends State<LogisticaDetailScreen> {
  Map<String, dynamic>? logisticaDetail;
  List<dynamic> registros = [];
  List<String?> ubicacionesSeleccionadas = [];
  bool isLoading = true;
  String? errorMessage;

  static const List<String> ubicaciones = [
    "PT1-C01",
    "PT1-C02",
    "PT1-C03",
    "PT1-C04",
    "PT1-C05",
    "PT1-C06",
    "PT1-C07",
    "PT1-C08",
    "PT1-EMBARQUES",
    "PT1-PASO1",
    "PT1-PASO4",
    "PT1-PASO5",
    "PT1-PASO6",
    "PT1-PASO8",
    "PT1-RAA-L1",
    "PT1-RB-L1",
    "PT1-RB-L2",
    "PT1-RD-L1",
    "PT1-RD-L2",
    "PT1-RE-L1",
    "PT1-RE-L2",
    "PT1-REPROCESOS",
    "PT1-RF-L1",
    "PT1-RF-L2",
    "PT1-RG-L1",
    "PT1-RG-L2",
    "PT1-RH-L1",
    "PT1-RH-L2",
    "PT1-RR-L1",
    "PT1-RR-L2",
    "PT1-RU-L1",
    "PT1-RU-L2",
    "PT1-RV-L1",
    "PT1-RV-L2",
    "PT1-RZ-L1",
    "PT1-RZ-L2",
    "PT1-UBICACIÓN-DE-SISTEMA"
  ];

  static const Map<String, Color> semaforoColors = {
    'ROJO': Colors.red,
    'NARANJA': Colors.orange,
    'VERDE': Colors.green,
    'AZUL': Colors.blue,
    'AMARILLO': Color.fromARGB(255, 239, 170, 0),
  };

  @override
  void initState() {
    super.initState();
    _fetchLogisticaDetail();
  }

  // Convert any value to string safely
  String _safeToString(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toString();
    return value.toString();
  }

  Future<void> _fetchLogisticaDetail() async {
    try {
      setState(() => isLoading = true);
      final response = await http
          .get(Uri.parse(
              'http://172.16.10.31/api/Logistica/${widget.noLogistica}'))
          .timeout(Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          logisticaDetail = data;
          registros = data['registros'] ?? [];
          ubicacionesSeleccionadas =
              List<String?>.filled(registros.length, null);
          isLoading = false;
          errorMessage = null;
        });
      } else {
        throw Exception("Error en la respuesta: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Error al cargar los detalles: $e";
        isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Color _getCardColor(String semaforo) {
    return semaforoColors[semaforo.toUpperCase()] ?? Colors.grey;
  }

  Widget _buildHeaderInfo(String title, dynamic value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(width: 10),
        Text(
          '$title:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            _safeToString(value),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getCardColor(logisticaDetail?['semaforo']?.toString() ?? ''),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Logística ${_safeToString(logisticaDetail?['nO_LOGISTICA'])}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _safeToString(logisticaDetail?['semaforo']).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: Colors.white54, thickness: 1, height: 20),
          SizedBox(height: 10),
          _buildHeaderInfo(
            'Cliente',
            logisticaDetail?['cliente'],
            Icons.person,
          ),
          SizedBox(height: 10),
          _buildHeaderInfo(
            'Fecha Programada',
            logisticaDetail?['fechaProg']?.toString().split(' ')[0],
            Icons.calendar_today,
          ),
        ],
      ),
    );
  }

// Modifica el método _buildRegistroItem:
  Widget _buildRegistroItem(dynamic registro, int index) {
    // Obtener el color basado en el estatus
    Color statusColor = _getCardColor(registro['semaforo']?.toString() ?? '');
    String estatus = _safeToString(registro['estatus2']);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _safeToString(registro['producto']),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Pedido: ${_safeToString(registro['pedido'])}',
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRowWithColor(
                            'Clave de Producto:',
                            registro['itemCode'],
                            statusColor,
                          ),
                          _buildInfoRowWithColor(
                            'Programado:',
                            registro['programado'],
                            statusColor,
                          ),
                          _buildInfoRowWithColor(
                            'Clave Unidad:',
                            registro['unidad'],
                            statusColor,
                          ),
                          _buildInfoRowWithColor(
                            'Comentarios:',
                            registro['coments'],
                            statusColor,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estatus:',
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                estatus,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                _buildUbicacionDropdownWithColor(index, statusColor),
              ],
            ),
          ),
          MaterialSeparationWidget(registro: registro),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithColor(String label, dynamic value, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 5),
          Expanded(
            child: Text(
              _safeToString(value),
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUbicacionDropdownWithColor(int index, Color color) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ubicacionesSeleccionadas[index],
          hint: Text(
            'Seleccionar ubicación',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: color),
          items: ubicaciones.map((ubicacion) {
            return DropdownMenuItem<String>(
              value: ubicacion,
              child: Text(
                ubicacion,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              ubicacionesSeleccionadas[index] = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildUbicacionDropdown(int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ubicacionesSeleccionadas[index],
          hint: Text(
            'Seleccionar ubicación',
            style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          items: ubicaciones.map((ubicacion) {
            return DropdownMenuItem<String>(
              value: ubicacion,
              child: Text(
                ubicacion,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              ubicacionesSeleccionadas[index] = value;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle Logística ${widget.noLogistica}'),
        backgroundColor:
            _getCardColor(logisticaDetail?['semaforo']?.toString() ?? ''),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchLogisticaDetail,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchLogisticaDetail,
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: registros.isEmpty
                          ? Center(
                              child: Text(
                                "No hay registros disponibles",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: registros.length,
                              itemBuilder: (context, index) =>
                                  _buildRegistroItem(registros[index], index),
                            ),
                    ),
                  ],
                ),
    );
  }
}
