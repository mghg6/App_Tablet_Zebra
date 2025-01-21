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
  List<dynamic> logisticasFiltradas = [];
  bool isLoading = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();

  // Variables para los filtros
  String? auxVentasSeleccionado;
  String? estatusSeleccionado;
  String? diasSeleccionado;
  String? completadoSeleccionado;

  // Sets para almacenar valores únicos para los filtros
  Set<String> auxVentasOpciones = {};
  Set<String> estatusOpciones = {};
  Set<String> diasOpciones = {};
  Set<String> completadoOpciones = {};

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
        final data = json.decode(response.body);
        setState(() {
          logisticas = data;
          logisticasFiltradas = data;
          _actualizarOpcionesFiltros();
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

  void _actualizarOpcionesFiltros() {
    auxVentasOpciones.clear();
    estatusOpciones.clear();
    diasOpciones.clear();
    completadoOpciones.clear();

    for (var logistica in logisticas) {
      // Agregar opciones de Aux Ventas
      if (logistica['auxVentas'] != null) {
        auxVentasOpciones.add(logistica['auxVentas'].toString());
      }

      // Procesar detalles para otros filtros
      List<dynamic> detalles = logistica['detalles'] ?? [];
      for (var detalle in detalles) {
        if (detalle['estatus2'] != null) {
          estatusOpciones.add(detalle['estatus2'].toString());
        }
        if (detalle['dias'] != null) {
          diasOpciones.add(detalle['dias'].toString());
        }
        if (detalle['completado'] != null) {
          completadoOpciones.add(detalle['completado'].toString());
        }
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      logisticasFiltradas = logisticas.where((logistica) {
        bool cumpleFiltros = true;

        // Filtro de Aux Ventas
        if (auxVentasSeleccionado != null) {
          cumpleFiltros = cumpleFiltros &&
              logistica['auxVentas']?.toString() == auxVentasSeleccionado;
        }

        // Filtros basados en detalles
        if (estatusSeleccionado != null ||
            diasSeleccionado != null ||
            completadoSeleccionado != null) {
          List<dynamic> detalles = logistica['detalles'] ?? [];
          bool cumpleDetalles = detalles.any((detalle) {
            bool cumpleDetalle = true;

            if (estatusSeleccionado != null) {
              cumpleDetalle = cumpleDetalle &&
                  detalle['estatus2']?.toString() == estatusSeleccionado;
            }
            if (diasSeleccionado != null) {
              cumpleDetalle = cumpleDetalle &&
                  detalle['dias']?.toString() == diasSeleccionado;
            }
            if (completadoSeleccionado != null) {
              cumpleDetalle = cumpleDetalle &&
                  detalle['completado']?.toString() == completadoSeleccionado;
            }

            return cumpleDetalle;
          });
          cumpleFiltros = cumpleFiltros && cumpleDetalles;
        }

        return cumpleFiltros;
      }).toList();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      auxVentasSeleccionado = null;
      estatusSeleccionado = null;
      diasSeleccionado = null;
      completadoSeleccionado = null;
      logisticasFiltradas = logisticas;
    });
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
    List<dynamic> detalles = logistica['detalles'] ?? [];
    // Color base del diseño
    Color baseColor = Color(0xFF85B6C4);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withOpacity(0.1),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: baseColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogisticaDetailScreen(
                noLogistica: logistica['nO_LOGISTICA'],
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: baseColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: baseColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${_safeToString(logistica['nO_LOGISTICA'])}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            'Logística',
                            style: TextStyle(
                              fontSize: 13,
                              color: baseColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Información Principal
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Primera columna - Cliente
                      Expanded(
                        child: _buildColumnInfoItem(
                          Icons.business,
                          'Cliente',
                          _safeToString(logistica['cliente']),
                          Colors.indigo, // Color principal para Cliente
                        ),
                      ),
                      // Separador vertical
                      VerticalDivider(
                        color: Colors.grey[200],
                        width: 20,
                      ),
                      // Segunda columna - Aux Ventas
                      Expanded(
                        child: _buildColumnInfoItem(
                          Icons.person_outline,
                          'Aux Ventas',
                          _safeToString(logistica['auxVentas']),
                          Colors.teal, // Color principal para Aux Ventas
                        ),
                      ),
                      // Separador vertical
                      VerticalDivider(
                        color: Colors.grey[200],
                        width: 20,
                      ),
                      // Tercera columna - Programado
                      Expanded(
                        child: _buildColumnInfoItem(
                          Icons.calendar_today_outlined,
                          'Programado',
                          logistica['fechaProg']?.toString().split(' ')[0] ??
                              'N/A',
                          Colors.deepPurple, // Color principal para Programado
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Detalles Header
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Detalles',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Detalles Content
                detalles.isEmpty
                    ? Center(
                        child: Text(
                          'Sin detalles',
                          style: TextStyle(
                            color: baseColor.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Column(
                        children: detalles
                            .map((detalle) => _buildDetalleItem(detalle))
                            .toList(),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColumnInfoItem(
      IconData icon, String label, String value, Color baseColor) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: baseColor,
                ),
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: baseColor.shade700,
              height: 1.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfoItem(
      IconData icon, String label, String value, Color baseColor) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: baseColor,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: baseColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
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

    // Obtener el color del semáforo
    Color semaforoColor =
        semaforoColors[detalle['semaforo']?.toString().toUpperCase()] ??
            Colors.grey;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            semaforoColor.withOpacity(0.15),
            semaforoColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: semaforoColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: semaforoColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primera fila: Estatus y Código de Item
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isRetrasado
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRetrasado
                        ? Colors.red.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _safeToString(detalle['estatus2']),
                  style: TextStyle(
                    fontSize: 12,
                    color: isRetrasado ? Colors.red[700] : Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 4),
                    Text(
                      _safeToString(detalle['itemCode']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Segunda fila: Información de días
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: semaforoColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _safeToString(detalle['dia']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_safeToString(detalle['dias'])} días',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Tercera fila: Stock e Inventario
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.purple[700],
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Stock: ${_safeToString(detalle['stock'])}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      color: Colors.blue[700],
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Diferencia: ${_safeToString(detalle['diferencia'])}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      (isFalta ? Colors.orange : Colors.green).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isFalta ? Colors.orange : Colors.green)
                        .withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFalta
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: isFalta ? Colors.orange[700] : Colors.green[700],
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _safeToString(detalle['completado']),
                      style: TextStyle(
                        fontSize: 13,
                        color: isFalta ? Colors.orange[700] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // Filtro Aux Ventas
          PopupMenuButton<String>(
            icon: Icon(Icons.person_outline),
            tooltip: 'Filtrar por Aux Ventas',
            onSelected: (String value) {
              setState(() {
                auxVentasSeleccionado = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: null,
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    auxVentasSeleccionado = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...auxVentasOpciones.map((String value) => PopupMenuItem(
                    value: value,
                    child: Text(value),
                  )),
            ],
          ),
          // Filtro Estatus
          PopupMenuButton<String>(
            icon: Icon(Icons.assignment_outlined),
            tooltip: 'Filtrar por Estatus',
            onSelected: (String value) {
              setState(() {
                estatusSeleccionado = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: null,
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    estatusSeleccionado = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...estatusOpciones.map((String value) => PopupMenuItem(
                    value: value,
                    child: Text(value),
                  )),
            ],
          ),
          // Filtro Días
          PopupMenuButton<String>(
            icon: Icon(Icons.calendar_today),
            tooltip: 'Filtrar por Días',
            onSelected: (String value) {
              setState(() {
                diasSeleccionado = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: null,
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    diasSeleccionado = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...diasOpciones.map((String value) => PopupMenuItem(
                    value: value,
                    child: Text(value),
                  )),
            ],
          ),
          // Filtro Completado
          PopupMenuButton<String>(
            icon: Icon(Icons.check_circle_outline),
            tooltip: 'Filtrar por Completado',
            onSelected: (String value) {
              setState(() {
                completadoSeleccionado = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: null,
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    completadoSeleccionado = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...completadoOpciones.map((String value) => PopupMenuItem(
                    value: value,
                    child: Text(value),
                  )),
            ],
          ),
          // Botón para limpiar filtros
          IconButton(
            icon: Icon(Icons.filter_list_off),
            onPressed: _limpiarFiltros,
            tooltip: 'Limpiar filtros',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchLogisticas,
            tooltip: 'Recargar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(auxVentasSeleccionado != null ||
                  estatusSeleccionado != null ||
                  diasSeleccionado != null ||
                  completadoSeleccionado != null
              ? 30
              : 0),
          child: _buildFiltrosActivos(),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                  child: logisticasFiltradas.isEmpty
                      ? Center(
                          child: Text(
                            'No hay logísticas que coincidan con los filtros',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: logisticasFiltradas.length,
                          itemBuilder: (context, index) {
                            return _buildLogisticaCard(
                                logisticasFiltradas[index]);
                          },
                        ),
                ),
    );
  }

  Widget _buildFiltrosActivos() {
    List<Widget> chips = [];

    if (auxVentasSeleccionado != null) {
      chips.add(_buildFilterChip('Aux Ventas: $auxVentasSeleccionado', () {
        setState(() {
          auxVentasSeleccionado = null;
          _aplicarFiltros();
        });
      }));
    }

    if (estatusSeleccionado != null) {
      chips.add(_buildFilterChip('Estatus: $estatusSeleccionado', () {
        setState(() {
          estatusSeleccionado = null;
          _aplicarFiltros();
        });
      }));
    }

    if (diasSeleccionado != null) {
      chips.add(_buildFilterChip('Días: $diasSeleccionado', () {
        setState(() {
          diasSeleccionado = null;
          _aplicarFiltros();
        });
      }));
    }

    if (completadoSeleccionado != null) {
      chips.add(_buildFilterChip('Completado: $completadoSeleccionado', () {
        setState(() {
          completadoSeleccionado = null;
          _aplicarFiltros();
        });
      }));
    }

    return chips.isEmpty
        ? Container()
        : Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: Icon(Icons.close, size: 18),
        onDeleted: onDelete,
      ),
    );
  }
}

extension on Color {
  get shade700 => null;
}
