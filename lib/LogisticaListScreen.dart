import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:zebra_scanner_app/LogisticaDetailScreen.dart'; // You'll need to create this file

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
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Variables para los filtros
  String? auxVentasSeleccionado;
  String? estatusSeleccionado;
  String? diasSeleccionado;
  String? completadoSeleccionado;
  String? noLogisticaSeleccionado;

  // Controlador para búsqueda por número de logística
  final TextEditingController noLogisticaSearchController =
      TextEditingController();
  bool isSearchVisible = false;

  // Sets para almacenar valores únicos para los filtros
  Set<String> auxVentasOpciones = {};
  Set<String> estatusOpciones = {};
  Set<String> diasOpciones = {};
  Set<String> completadoOpciones = {};

  // Lista de operadores
  final List<String> operadores = [
    'Jorge Lara Pachecho',
    'Luis Manuel Rodriguez Zacarias',
    'Adrian Chavez Marquez',
    'Luis Adrian Segura Aguilar',
    'Ramon Martinez Almaguer',
    'Jose Perez Gonzales',
    'Jose Garcia Torres',
    'Luz Marlén Sánchez Romero'
  ];

  // Operador seleccionado para la separación
  String? operadorSeleccionado;

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
    searchController.addListener(_onSearchChanged);
    noLogisticaSearchController.addListener(_onNoLogisticaSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    noLogisticaSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text;
      _aplicarFiltros();
    });
  }

  void _onNoLogisticaSearchChanged() {
    setState(() {
      noLogisticaSeleccionado = noLogisticaSearchController.text;
      _aplicarFiltros();
    });
  }

  String _safeToString(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toString();
    return value.toString();
  }

  Future<void> _fetchLogisticas() async {
    try {
      setState(() => isLoading = true);
      print('Iniciando petición a API: ${DateTime.now()}');

      final stopwatch = Stopwatch()..start();

      // Cambio del endpoint para obtener solo logísticas en separación
      final response = await http
          .get(Uri.parse(
              'http://172.16.10.31/api/Logistica/logisticas-separacion'))
          .timeout(Duration(seconds: 20), onTimeout: () {
        throw TimeoutException(
            'La solicitud ha excedido el tiempo de espera (15 segundos)');
      });

      print('Respuesta recibida en: ${stopwatch.elapsed.inMilliseconds}ms');

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Código de respuesta: ${response.statusCode}');
        print('Longitud de respuesta: ${response.body.length} bytes');

        try {
          final stopwatchDecode = Stopwatch()..start();
          final data = json.decode(response.body);
          print(
              'JSON decodificado en: ${stopwatchDecode.elapsed.inMilliseconds}ms');
          print('Número de registros recibidos: ${data.length}');

          setState(() {
            logisticas = data;
            logisticasFiltradas = data;
            _actualizarOpcionesFiltros();
            errorMessage = null;
            isLoading = false;
          });
        } catch (jsonError) {
          print('Error al decodificar JSON: $jsonError');
          throw Exception('Error al procesar la respuesta: $jsonError');
        }
      } else {
        print('Código de error: ${response.statusCode}');
        print('Cuerpo de respuesta: ${response.body}');
        throw Exception('Error en la respuesta: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Error de timeout: $e');
      if (!mounted) return;
      setState(() {
        errorMessage =
            'La solicitud ha excedido el tiempo de espera. Comprueba tu conexión a la red.';
        isLoading = false;
      });
      _showErrorSnackBar(errorMessage!);
    } on SocketException catch (e) {
      print('Error de conexión: $e');
      if (!mounted) return;
      setState(() {
        errorMessage =
            'No se pudo conectar al servidor. Verifica tu conexión de red.';
        isLoading = false;
      });
      _showErrorSnackBar(errorMessage!);
    } catch (e) {
      print('Error en _fetchLogisticas: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error al cargar las logísticas: ${e.toString()}';
        isLoading = false;
      });
      _showErrorSnackBar(errorMessage!);
    } finally {
      print('Finalizada petición API: ${DateTime.now()}');
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

      // Agregar opciones de Estatus
      if (logistica['estatus'] != null) {
        estatusOpciones.add(logistica['estatus'].toString());
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

        // Búsqueda por número de logística
        if (searchQuery.isNotEmpty) {
          String noLogistica =
              _safeToString(logistica['nO_LOGISTICA']).toLowerCase();
          cumpleFiltros =
              cumpleFiltros && noLogistica.contains(searchQuery.toLowerCase());
        }

        // Filtro por número de logística específico
        if (noLogisticaSeleccionado != null &&
            noLogisticaSeleccionado!.isNotEmpty) {
          String noLogistica = _safeToString(logistica['nO_LOGISTICA']);
          cumpleFiltros =
              cumpleFiltros && noLogistica == noLogisticaSeleccionado;
        }

        // Filtro de Aux Ventas
        if (auxVentasSeleccionado != null) {
          cumpleFiltros = cumpleFiltros &&
              logistica['auxVentas']?.toString() == auxVentasSeleccionado;
        }

        // Filtro de Estatus general
        if (estatusSeleccionado != null) {
          // Comprobar si coincide con el estatus general
          bool coincideEstatusGeneral =
              logistica['estatus']?.toString() == estatusSeleccionado;

          // Comprobar si coincide con algún estatus en los detalles
          List<dynamic> detalles = logistica['detalles'] ?? [];
          bool coincideEstatusDetalles = detalles.any((detalle) =>
              detalle['estatus2']?.toString() == estatusSeleccionado);

          cumpleFiltros = cumpleFiltros &&
              (coincideEstatusGeneral || coincideEstatusDetalles);
        }

        // Filtros basados en detalles
        if (diasSeleccionado != null || completadoSeleccionado != null) {
          List<dynamic> detalles = logistica['detalles'] ?? [];
          bool cumpleDetalles = detalles.any((detalle) {
            bool cumpleDetalle = true;

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
      noLogisticaSeleccionado = null;
      noLogisticaSearchController.clear();
      searchController.clear();
      searchQuery = '';
      isSearchVisible = false;
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

  // Método para confirmar separación - Actualizado para usar PUT en lugar de POST
  Future<void> _confirmarSeparacion(dynamic logistica) async {
    // Reset the selected operator
    operadorSeleccionado = null;

    // Show the confirmation modal
    final selectedOperator = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Confirmar Separación de Material'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logística: #${_safeToString(logistica['nO_LOGISTICA'])}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Cliente: ${_safeToString(logistica['cliente'])}'),
                    SizedBox(height: 8),
                    Text(
                        'Aux. Ventas: ${_safeToString(logistica['auxVentas'])}'),
                    SizedBox(height: 16),
                    Text('Seleccione el operador de separación:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('Seleccionar operador'),
                          value: operadorSeleccionado,
                          items: operadores.map((String operador) {
                            return DropdownMenuItem<String>(
                              value: operador,
                              child: Text(operador),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              operadorSeleccionado = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: operadorSeleccionado == null
                      ? null // Deshabilitar si no hay operador seleccionado
                      : () => Navigator.of(context).pop(operadorSeleccionado),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF46707e),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedOperator != null) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        // Obtener el número de logística
        final noLogistica = logistica['nO_LOGISTICA'];

        // Construir la URL con los parámetros de consulta
        final now = DateTime.now();
        final String formattedDate = now.toIso8601String();
        final String estatus = "En Separación de Material";

        // URL para la petición PUT
        final apiUrl = Uri.parse(
            'http://172.16.10.31/api/logistics_to_review/materialput/$noLogistica?estatus=$estatus&operador=$selectedOperator&lastUpdate=$formattedDate');

        print("🔗 URL de la petición: $apiUrl");

        // Hacer la petición PUT
        final response = await http.put(
          apiUrl,
          headers: {'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: 15));

        // Close loading indicator
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        // Log response for debugging
        print(
            "📫 Respuesta del servidor (${response.statusCode}): ${response.body}");

        if (response.statusCode == 200) {
          // Registro actualizado exitosamente
          _procesarRespuestaExitosa(response, logistica, selectedOperator);
        } else if (response.statusCode == 409) {
          // Registro existente o conflicto
          _manejarRegistroExistente(response, logistica, selectedOperator);
        } else {
          throw Exception(
              'Error en la respuesta: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        // Close loading indicator if it's still showing
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        print("❌ Error en la operación de separación: ${e.toString()}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error al actualizar registro de separación: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Método para procesar respuesta exitosa
  void _procesarRespuestaExitosa(
      http.Response response, dynamic logistica, String selectedOperator) {
    try {
      // Parse the response to get the ID
      final responseData = json.decode(response.body);
      print("Respuesta completa: $responseData");

      // Extraer los IDs - usar 0 como valor por defecto
      int separacionId = responseData['id'] ?? 0;

      // Intentar obtener el ID de revisión de diferentes formas posibles
      int? revisionId;
      if (responseData.containsKey('id_Revision')) {
        revisionId = responseData['id_Revision'];
      } else if (responseData.containsKey('idRevision')) {
        revisionId = responseData['idRevision'];
      } else if (responseData.containsKey('revision_id')) {
        revisionId = responseData['revision_id'];
      }

      // Si no se encontró el ID de revisión, buscar en la respuesta completa
      if (revisionId == null) {
        String responseStr = response.body;
        final RegExp idRevisionRegExp = RegExp(r'"id_Revision"\s*:\s*(\d+)');
        final match = idRevisionRegExp.firstMatch(responseStr);
        if (match != null && match.groupCount >= 1) {
          revisionId = int.tryParse(match.group(1)!) ?? 0;
        }
      }

      // Si todavía no se encuentra, asignar el mismo valor que separacionId
      revisionId ??= separacionId;

      print("🆔 ID de Separación obtenido: $separacionId");
      print("🆔 ID de Revisión obtenido: $revisionId");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registro de separación actualizado exitosamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _navegarALogisticaDetail(
          logistica, selectedOperator, separacionId, revisionId);
    } catch (parseError) {
      print("⚠️ Error al procesar la respuesta: $parseError");
      print("⚠️ Contenido de la respuesta: ${response.body}");

      _manejarErrorParseo(response, logistica, selectedOperator);
    }
  }

  // Método para manejar error de parseo
  void _manejarErrorParseo(
      http.Response response, dynamic logistica, String selectedOperator) {
    // En caso de error, intentar enviar la logística sin revisionId
    int separacionId = 0;
    try {
      final responseData = json.decode(response.body);
      if (responseData.containsKey('id')) {
        separacionId = responseData['id'];
      }
    } catch (e) {
      print("⚠️ Error adicional al intentar procesar id: $e");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Advertencia: Registro actualizado, pero hubo error al procesar la respuesta'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _navegarALogisticaDetail(
        logistica, selectedOperator, separacionId, separacionId);
  }

  // Método para manejar registro existente
  void _manejarRegistroExistente(http.Response response, dynamic logistica,
      String selectedOperator) async {
    try {
      final responseData = json.decode(response.body);
      print("Respuesta de error por duplicado: $responseData");

      // Extraer mensaje, ID de revisión, estatus y operador actual
      String mensaje = responseData['message'] ?? 'Registro duplicado';
      int revisionId = responseData['id_Revision'] ?? 0;
      String estatus = responseData['estatus'] ?? 'Desconocido';

      // Extraer el operador actual del registro existente (si está disponible)
      // Usar el nombre correcto del campo según la respuesta del backend: 'operador'
      String operadorActual = responseData['operador'] ?? '';

      // Verificar si el operador seleccionado es el mismo que el del registro
      bool mismoOperador =
          operadorActual.toLowerCase() == selectedOperator.toLowerCase();

      // Mostrar diálogo con la información
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Registro Existente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensaje),
                SizedBox(height: 12),
                Text('ID de Revisión: $revisionId'),
                Text('Estatus actual: $estatus'),
                if (operadorActual.isNotEmpty)
                  Text('Operador actual: $operadorActual'),
              ],
            ),
            actions: [
              // Si es el mismo operador, permitir continuar sin cambiar el estado
              if (mismoOperador)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navegar directamente al detalle sin cambiar el estado
                    _navegarALogisticaDetail(
                        logistica, selectedOperator, revisionId, revisionId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text('Continuar con el mismo operador'),
                ),
              // Si es un estatus rechazado, permitir reanudar la separación
              if (estatus == "Rechazado en Separación de Producto")
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _cambiarEstatusRechazado(
                        revisionId, logistica, selectedOperator);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF46707e),
                  ),
                  child: Text('Reanudar Separación'),
                ),
              // Si no es el mismo operador y no es rechazado, solo mostrar botón de entendido
              if (!mismoOperador &&
                  estatus != "Rechazado en Separación de Producto")
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Entendido'),
                ),
            ],
          );
        },
      );
    } catch (e) {
      print("⚠️ Error al procesar respuesta de duplicado: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error al procesar la respuesta. No se puede continuar con la separación.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para cambiar el estatus en caso de registro rechazado
  Future<void> _cambiarEstatusRechazado(
      int revisionId, dynamic logistica, String selectedOperator) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // URL para actualizar el estatus
      final apiUrl =
          'http://172.16.10.31/api/logistics_to_review/$revisionId/status';
      print("🔗 URL para actualización de estatus: $apiUrl");

      // Hacer la petición PUT para actualizar el estatus
      final response = await http
          .put(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode("En Separación de Material"),
          )
          .timeout(Duration(seconds: 15));

      // Cerrar indicador de carga
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print(
          "📫 Respuesta de actualización (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200) {
        // Parsear la respuesta
        final responseData = json.decode(response.body);
        final record = responseData['record'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Estatus actualizado correctamente. Continuando con la separación.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navegar a la pantalla de detalle con la información
        _navegarALogisticaDetail(logistica, selectedOperator,
            record['id_Revision'] ?? 0, record['id_Revision'] ?? 0);
      } else {
        throw Exception(
            'Error al actualizar estatus: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Close loading indicator if it's still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print("❌ Error al actualizar estatus: ${e.toString()}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar estatus: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para navegar a la pantalla de detalle
  void _navegarALogisticaDetail(
      dynamic logistica, String operador, int separacionId, int revisionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogisticaDetailScreen(
          noLogistica: logistica['nO_LOGISTICA'],
          operador: operador,
          separacionId: separacionId,
          revisionId: revisionId,
          logisticaCompleta: logistica,
        ),
      ),
    );
  }

  Color _getCardColor(String? semaforo) {
    return semaforoColors[semaforo?.toUpperCase() ?? ''] ?? Colors.grey;
  }

  // Método para determinar el color del estatus
  Color _getEstatusColor(String estatus) {
    if (estatus == null || estatus == 'Sin Estatus') {
      return Colors.grey;
    }

    // Estatus de rechazo
    if (estatus == "Rechazado en Separación de Producto" ||
        estatus == "Rechazado en Revisión de Calidad") {
      return Colors.deepOrange.shade700;
    }

    // Éxito - procesos completados o aprobados
    if (estatus == 'Embarque Completado' ||
        estatus == 'Facturado' ||
        estatus == 'Entregado' ||
        estatus == 'Validado por las Antenas' ||
        estatus == 'Aprobado en Revisión de Calidad' ||
        estatus == 'Validado por Aduana') {
      return Colors.green.shade700;
    }

    // Advertencia - en proceso
    if (estatus.startsWith('En ') ||
        estatus == 'Material Separado' ||
        estatus == 'En Tránsito') {
      return Colors.orange.shade700;
    }

    // Información - observaciones y estados intermedios
    if (estatus == 'Aprobado con Observaciones en Calidad' ||
        estatus == 'Evidencias Cargadas' ||
        estatus == 'Carril Asignado por Aduana') {
      return Colors.blue.shade700;
    }

    // Por defecto
    return Colors.grey.shade700;
  }

  Widget _buildLogisticaCard(dynamic logistica) {
    List<dynamic> detalles = logistica['detalles'] ?? [];
    // Color base del diseño
    Color baseColor = Color(0xFF85B6C4);

    // Estatus de la logística
    String estatus = logistica['estatus'] ?? 'Sin Estatus';

    // Determinar el color del estatus basado en su valor
    Color estatusColor = _getEstatusColor(estatus);

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
          onTap: () {
            // Show action bottom sheet
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (BuildContext context) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: 20,
                      left: 20,
                      right: 20,
                      bottom: 20 +
                          MediaQuery.of(context)
                              .padding
                              .bottom, // Padding adicional para el área segura
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Acciones para Logística #${_safeToString(logistica['nO_LOGISTICA'])}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 20),
                        ListTile(
                          leading: Icon(Icons.assignment, color: baseColor),
                          title: Text('Iniciar Separación de Material'),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            _confirmarSeparacion(logistica);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header modificado para incluir estatus
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
                    // Estatus Badge - Se añade a la derecha con texto blanco
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            estatusColor, // Color sólido en lugar de transparencia
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        estatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white, // Texto blanco como solicitaste
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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

                // Botón para iniciar separación
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmarSeparacion(logistica),
                    icon: Icon(Icons.assignment_outlined),
                    label: Text('Iniciar Separación de Material'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: baseColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
              color: baseColor,
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
        title: isSearchVisible
            ? TextField(
                controller: noLogisticaSearchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por No. Logística',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      noLogisticaSearchController.clear();
                      setState(() {
                        isSearchVisible = false;
                        noLogisticaSeleccionado = null;
                        _aplicarFiltros();
                      });
                    },
                  ),
                ),
                style: TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  setState(() {
                    noLogisticaSeleccionado = value;
                    _aplicarFiltros();
                  });
                },
              )
            : Text('Consulta de Logística'),
        actions: [
          // Icono de búsqueda para No. Logística
          IconButton(
            icon: Icon(isSearchVisible ? Icons.search_off : Icons.search),
            tooltip: 'Buscar por No. Logística',
            onPressed: () {
              setState(() {
                isSearchVisible = !isSearchVisible;
                if (!isSearchVisible) {
                  noLogisticaSearchController.clear();
                  noLogisticaSeleccionado = null;
                  _aplicarFiltros();
                }
              });
            },
          ),
          // Filtro Aux Ventas
          if (!isSearchVisible)
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
          if (!isSearchVisible)
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
          if (!isSearchVisible)
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
          if (!isSearchVisible)
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
          if (!isSearchVisible)
            IconButton(
              icon: Icon(Icons.filter_list_off),
              onPressed: _limpiarFiltros,
              tooltip: 'Limpiar filtros',
            ),
          // Botón para recargar
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
                  completadoSeleccionado != null ||
                  (noLogisticaSeleccionado != null &&
                      noLogisticaSeleccionado!.isNotEmpty)
              ? 30
              : 0),
          child: _buildFiltrosActivos(),
        ),
      ),
      body: SafeArea(
        child: isLoading
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
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: 8,
                            ),
                            itemCount: logisticasFiltradas.length,
                            itemBuilder: (context, index) {
                              return _buildLogisticaCard(
                                  logisticasFiltradas[index]);
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _buildFiltrosActivos() {
    List<Widget> chips = [];

    if (noLogisticaSeleccionado != null &&
        noLogisticaSeleccionado!.isNotEmpty) {
      chips.add(_buildFilterChip('No. Logística: $noLogisticaSeleccionado', () {
        setState(() {
          noLogisticaSeleccionado = null;
          noLogisticaSearchController.clear();
          _aplicarFiltros();
        });
      }));
    }

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
