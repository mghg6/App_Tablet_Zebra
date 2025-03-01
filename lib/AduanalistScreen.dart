import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zebra_scanner_app/scanandcapture.dart';
import 'dart:convert'; // Importar la pantalla existente

class AduanaReviewScreen extends StatefulWidget {
  const AduanaReviewScreen({Key? key}) : super(key: key);

  @override
  _AduanaReviewScreenState createState() => _AduanaReviewScreenState();
}

class _AduanaReviewScreenState extends State<AduanaReviewScreen> {
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
  String? selectedOperador;

  // Sets para almacenar valores únicos para los filtros
  Set<String> logisticasOpciones = {};
  Set<String> clientesOpciones = {};
  Set<String> operadoresOpciones = {};

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      setState(() => isLoading = true);

      // Modificamos la URL para obtener solo las logísticas con los estatus deseados
      final response = await http
          .get(Uri.parse(
              'http://172.16.10.31/api/logistics_to_review/status/aprobado'))
          .timeout(Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Filtramos solo los estatus que nos interesan
          reviews = data
              .where((review) =>
                  review['estatus'] ==
                      "Aprobado con Observaciones en Calidad" ||
                  review['estatus'] == "Aprobado en Revisión de Calidad")
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
        errorMessage = 'Error al cargar las revisiones: ${e.toString()}';
        isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _showStartReviewDialog(dynamic review) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.assignment_outlined,
                  color: Theme.of(context).primaryColor),
              SizedBox(width: 8),
              Text('Iniciar Revisión de Aduana'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '¿Deseas comenzar la revisión de aduana para la logística #${review['no_Logistica']}?'),
              SizedBox(height: 12),
              Text(
                'Cliente: ${review['cliente']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
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
              onPressed: () => _startReview(review),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startReview(dynamic review) async {
    try {
      // Actualizamos el estado a "En Revisión por Aduana"
      final response = await http.put(
        Uri.parse(
            'http://172.16.10.31/api/logistics_to_review/${review['id_Revision']}/status'),
        body: json.encode("En Revisión por Aduana"),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).pop(); // Cerrar diálogo

        // Decodificar la lista de trazabilidades para cargar los EPCs iniciales
        List<String> trazabilidadesList = [];
        try {
          final decoded = json.decode(review['lista_Trazabilidades'] ?? '[]');
          if (decoded is List) {
            trazabilidadesList = List<String>.from(decoded);
          }
        } catch (e) {
          print('Error decoding trazabilidades: $e');
        }

        // Navegar a ScanAndCapture con todos los datos necesarios
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanAndCapture(
              reviewId: review['id_Revision'],
              noLogistica: review['no_Logistica'],
              cliente: review['cliente'],
              operador: review['operador_Separador'],
              trazabilidadesList: trazabilidadesList,
              aduanaReview: true,
              reviewStatus: "En Revisión por Aduana",
              previousStatus: review['estatus'], // Estado anterior
            ),
          ),
        ).then((_) => _fetchReviews());
      } else {
        throw Exception('Error al actualizar estado: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar la revisión: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _actualizarOpcionesFiltros() {
    logisticasOpciones.clear();
    clientesOpciones.clear();
    operadoresOpciones.clear();

    for (var review in reviews) {
      if (review['no_Logistica'] != null) {
        logisticasOpciones.add(review['no_Logistica'].toString());
      }
      if (review['cliente'] != null) {
        clientesOpciones.add(review['cliente'].toString());
      }
      if (review['operador_Separador'] != null) {
        operadoresOpciones.add(review['operador_Separador'].toString());
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
        if (selectedOperador != null) {
          cumpleFiltros = cumpleFiltros &&
              review['operador_Separador'].toString() == selectedOperador;
        }

        return cumpleFiltros;
      }).toList();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      selectedLogistica = null;
      selectedCliente = null;
      selectedOperador = null;
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
    // Color basado en el estatus
    Color statusColor = review['estatus'] == "Aprobado en Revisión de Calidad"
        ? Colors.green
        : Colors.amber;

    return GestureDetector(
      onTap: () => _showStartReviewDialog(review),
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
                Colors.blue
                    .shade50, // Cambiamos a un tono azul para diferenciar de la vista de calidad
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
                        color: statusColor.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(innerContainerRadius),
                        border: Border.all(
                          color: statusColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        review['estatus'],
                        style: TextStyle(
                          color: statusColor.withOpacity(0.8),
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
                        icon: Icons.tag,
                        label: 'EPCs escaneados',
                        value: '${review['noEPCs']}',
                        iconColor: Colors.orange,
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text('Revisión de Aduana'),
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
          PopupMenuButton<String>(
            icon: Icon(Icons.person),
            tooltip: 'Filtrar por Operador',
            onSelected: (value) {
              setState(() {
                selectedOperador = value;
                _aplicarFiltros();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Todos'),
                onTap: () {
                  setState(() {
                    selectedOperador = null;
                    _aplicarFiltros();
                  });
                },
              ),
              ...operadoresOpciones.map((value) => PopupMenuItem(
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
                                    'No hay revisiones que coincidan con los filtros',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.only(
                                    top: 8,
                                    bottom: bottomPadding + 8,
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
