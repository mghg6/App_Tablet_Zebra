import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:zebra_scanner_app/CarrilSelectionScreen.dart';

class AsignacionCarrilListScreen extends StatefulWidget {
  const AsignacionCarrilListScreen({Key? key}) : super(key: key);

  @override
  _AsignacionCarrilListScreenState createState() =>
      _AsignacionCarrilListScreenState();
}

class _AsignacionCarrilListScreenState
    extends State<AsignacionCarrilListScreen> {
  List<dynamic> reviews = [];
  List<dynamic> filteredReviews = [];
  bool isLoading = true;
  String? errorMessage;

  // Constantes de diseño
  final cardBorderRadius = 16.0;
  final innerContainerRadius = 12.0;
  final elementBorderRadius = 8.0;

  // Variables para los filtros
  String? selectedLogistica;
  String? selectedCliente;
  String? selectedAuxiliarVentas;

  // Sets para almacenar valores únicos para los filtros
  Set<String> logisticasOpciones = {};
  Set<String> clientesOpciones = {};
  Set<String> auxiliaresVentasOpciones = {};

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      setState(() => isLoading = true);

      final response = await http
          .get(Uri.parse(
              'http://172.16.10.31/api/logistics_to_review/status/aduana'))
          .timeout(Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Filtramos solo los con estatus "Evidencias Cargadas"
          reviews = data
              .where((review) => review['estatus'] == "Evidencias Cargadas")
              .toList();

          filteredReviews = reviews;
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

  void _showStartAssignmentDialog(dynamic review) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.local_shipping, color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text('Asignar carril'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Quieres comenzar a asignar el carril para la logística #${review['no_Logistica']}?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Cliente: ${review['cliente']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Estado actual: ${review['estatus']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Comenzar'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarrilSelectionScreen(review: review),
                  ),
                ).then((_) => _fetchReviews());
              },
            ),
          ],
        );
      },
    );
  }

  void _actualizarOpcionesFiltros() {
    logisticasOpciones.clear();
    clientesOpciones.clear();
    auxiliaresVentasOpciones.clear();

    for (var review in reviews) {
      if (review['no_Logistica'] != null) {
        logisticasOpciones.add(review['no_Logistica'].toString());
      }
      if (review['cliente'] != null) {
        clientesOpciones.add(review['cliente'].toString());
      }
      if (review['auxiliarVentas'] != null) {
        auxiliaresVentasOpciones.add(review['auxiliarVentas'].toString());
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      filteredReviews = reviews.where((review) {
        bool cumpleFiltros = true;

        if (selectedLogistica != null) {
          cumpleFiltros = cumpleFiltros &&
              review['no_Logistica'].toString() == selectedLogistica;
        }
        if (selectedCliente != null) {
          cumpleFiltros =
              cumpleFiltros && review['cliente'].toString() == selectedCliente;
        }
        if (selectedAuxiliarVentas != null) {
          cumpleFiltros = cumpleFiltros &&
              review['auxiliarVentas'].toString() == selectedAuxiliarVentas;
        }

        return cumpleFiltros;
      }).toList();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      selectedLogistica = null;
      selectedCliente = null;
      selectedAuxiliarVentas = null;
      filteredReviews = reviews;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: _fetchReviews,
          textColor: Colors.white,
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr).toLocal();
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildReviewCard(dynamic review) {
    return GestureDetector(
      onTap: () => _showStartAssignmentDialog(review),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardBorderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.green.shade50, // Verde suave para esta vista
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius:
                            BorderRadius.circular(innerContainerRadius),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Logística #${review['no_Logistica']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(innerContainerRadius),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        review['estatus'],
                        style: TextStyle(
                          color: Colors.green.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(innerContainerRadius),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRowEnhanced(
                        icon: Icons.business,
                        label: 'Cliente',
                        value: review['cliente'],
                        iconColor: Colors.indigo,
                      ),
                      Divider(height: 16),
                      _buildInfoRowEnhanced(
                        icon: Icons.person,
                        label: 'Operador',
                        value: review['operador_Separador'],
                        iconColor: Colors.teal,
                      ),
                      Divider(height: 16),
                      _buildInfoRowEnhanced(
                        icon: Icons.support_agent,
                        label: 'Auxiliar de Ventas',
                        value: review['auxiliarVentas'] ?? 'No asignado',
                        iconColor: Colors.purple,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(elementBorderRadius),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.update,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Última actualización: ${_formatDateTime(review['lastUpdate'])}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(elementBorderRadius),
                    border: Border.all(
                      color: Colors.orange.shade300,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showStartAssignmentDialog(review),
                      borderRadius: BorderRadius.circular(elementBorderRadius),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: Colors.orange.shade800,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Asignar Carril',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowEnhanced({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(elementBorderRadius),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
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
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtener el padding del sistema para la navegación
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text('Asignación de Carril'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'Filtrar por No. Logística',
            onSelected: (value) {
              setState(() {
                selectedLogistica = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    selectedLogistica = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...logisticasOpciones.map((value) => PopupMenuItem(
                    value: value,
                    child: Text('#$value'),
                  )),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.business),
            tooltip: 'Filtrar por Cliente',
            onSelected: (value) {
              setState(() {
                selectedCliente = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    selectedCliente = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...clientesOpciones.map((value) => PopupMenuItem(
                    value: value,
                    child: Text(value),
                  )),
            ],
          ),
          IconButton(
            icon: Icon(Icons.filter_list_off),
            onPressed: _limpiarFiltros,
            tooltip: 'Limpiar filtros',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchReviews,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: SafeArea(
        // Con bottom: false para manejar manualmente el padding inferior
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchReviews,
                                icon: Icon(Icons.refresh),
                                label: Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchReviews,
                          child: filteredReviews.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay logísticas que coincidan con los filtros',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  // Agregar padding inferior adicional para evitar la barra de navegación
                                  padding: EdgeInsets.only(
                                    top: 8,
                                    // Usar viewPadding en lugar de padding.bottom
                                    bottom:
                                        bottomPadding + 16, // Espacio adicional
                                    left: 8,
                                    right: 8,
                                  ),
                                  itemCount: filteredReviews.length,
                                  itemBuilder: (context, index) {
                                    return _buildReviewCard(
                                        filteredReviews[index]);
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
