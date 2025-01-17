import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:zebra_scanner_app/LogisticaDetailScreen.dart';

class LogisticaListScreen extends StatefulWidget {
  const LogisticaListScreen({Key? key}) : super(key: key);

  @override
  _LogisticaListScreenState createState() => _LogisticaListScreenState();
}

class _LogisticaListScreenState extends State<LogisticaListScreen> {
  List<dynamic> logisticas = [];
  bool isLoading = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();

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
    _fetchLogisticas();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _safeToString(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toString();
    return value.toString();
  }

  Future<void> _fetchLogisticas() async {
    try {
      setState(() => isLoading = true);

      final response = await http
          .get(Uri.parse('http://172.16.10.31/api/Logistica'))
          .timeout(Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          logisticas = json.decode(response.body);
          errorMessage = null;
          isLoading = false;
        });
      } else {
        throw Exception('Error en la respuesta: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error al cargar las logísticas: ${e.toString()}';
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
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: _fetchLogisticas,
          textColor: Colors.white,
        ),
      ),
    );
  }

  Color _getCardColor(String? semaforo) {
    return semaforoColors[semaforo?.toUpperCase() ?? ''] ?? Colors.grey;
  }

  Widget _buildLogisticaCard(dynamic logistica) {
    final color = _getCardColor(logistica['semaforo']?.toString());
    List<dynamic> detalles = logistica['detalles'] ?? [];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogisticaDetailScreen(
                noLogistica: logistica['nO_LOGISTICA'],
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.local_shipping,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logística',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '#${_safeToString(logistica['nO_LOGISTICA'])}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _safeToString(logistica['semaforo']).toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Contenido Principal
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMainInfoItem(
                              Icons.business,
                              'Cliente',
                              _safeToString(logistica['cliente']),
                            ),
                            SizedBox(height: 12),
                            _buildMainInfoItem(
                              Icons.person_outline,
                              'Aux Ventas',
                              _safeToString(logistica['auxVentas']),
                            ),
                            SizedBox(height: 12),
                            _buildMainInfoItem(
                              Icons.calendar_today_outlined,
                              'Programado',
                              logistica['fechaProg']
                                      ?.toString()
                                      .split(' ')[0] ??
                                  'N/A',
                            ),
                          ],
                        ),
                      ),
                      // Separador
                      Container(
                        width: 1,
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                      // Columna derecha - Detalles
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: detalles.isEmpty
                              ? [
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Sin detalles',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  )
                                ]
                              : detalles
                                  .map((detalle) => _buildDetalleItem(detalle))
                                  .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetalleItem(Map<String, dynamic> detalle) {
    final bool isRetrasado =
        detalle['estatus2']?.toString().toLowerCase().contains('retraso') ??
            false;
    final bool isFalta =
        detalle['completado']?.toString().toLowerCase() == 'falta';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isRetrasado
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _safeToString(detalle['estatus2']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetalleInfo('Día', _safeToString(detalle['dia'])),
              _buildDetalleInfo('Días', _safeToString(detalle['dias'])),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isFalta
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: isFalta ? Colors.orange : Colors.green,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                _safeToString(detalle['completado']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleInfo(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchLogisticas,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _fetchLogisticas,
                        icon: Icon(Icons.refresh),
                        label: Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLogisticas,
                  child: logisticas.isEmpty
                      ? Center(
                          child: Text(
                            'No hay logísticas disponibles',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: logisticas.length,
                          itemBuilder: (context, index) {
                            return _buildLogisticaCard(logisticas[index]);
                          },
                        ),
                ),
    );
  }
}
