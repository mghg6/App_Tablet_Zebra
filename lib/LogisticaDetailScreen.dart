import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zebra_scanner_app/modals/quality_review_modal.dart';
import 'dart:convert';
import 'package:zebra_scanner_app/widgets/material_separation.dart';

class LogisticaDetailScreen extends StatefulWidget {
  final dynamic noLogistica;
  final String? operador;
  final int? separacionId;
  final int? revisionId; // Parámetro para el ID de revisión
  final dynamic logisticaCompleta;
  final String? initialStatus; // Estado inicial seleccionado
  final Map<int, GlobalKey<MaterialSeparationWidgetState>> _materialKeys = {};

  LogisticaDetailScreen({
    Key? key,
    required this.noLogistica,
    this.operador,
    this.separacionId,
    this.revisionId,
    this.logisticaCompleta,
    this.initialStatus,
  }) : super(key: key);

  @override
  _LogisticaDetailScreenState createState() => _LogisticaDetailScreenState();
}

class _LogisticaDetailScreenState extends State<LogisticaDetailScreen> {
  Map<String, dynamic>? logisticaDetail;
  List<dynamic> registros = [];
  List<String?> ubicacionesSeleccionadas = [];
  bool isLoading = true;
  String? errorMessage;
  late String selectedStatus;
  bool isProcessing = false;
  String? lastUpdate;

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
    // Inicializar el estado seleccionado con el valor del parámetro o el predeterminado
    selectedStatus = widget.initialStatus ?? "Material Separado";
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
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          logisticaDetail = data;
          registros = data['registros'] ?? [];
          ubicacionesSeleccionadas =
              List<String?>.filled(registros.length, null);

          // Inicializar las keys para cada registro
          for (var i = 0; i < registros.length; i++) {
            if (!widget._materialKeys.containsKey(i)) {
              widget._materialKeys[i] =
                  GlobalKey<MaterialSeparationWidgetState>();
            }
          }

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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
        const SizedBox(width: 10),
        Text(
          '$title:',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _safeToString(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Método actualizado para mostrar la modal de calidad y finalización
  void _showQualityReviewModal() {
    // Obtener todos los EPCs escaneados para esta logística específica
    List<String> allScannedEpcs =
        MaterialSeparationWidgetState.getEpcsByLogisticaId(
            widget.noLogistica.toString());

    // Ya no validamos que haya EPCs escaneados antes de mostrar el diálogo
    // para permitir continuar con el proceso de rechazo sin EPCs
    _showConfirmationDialog(allScannedEpcs);
  }

  // Diálogo de confirmación mejorado con indicación de procesamiento y finalización
  // Diálogo de confirmación mejorado con RadioButtons para garantizar selección
  void _showConfirmationDialog(List<String> allScannedEpcs) {
    String _dialogTempSelectedStatus = selectedStatus;
    bool _showFullList = false;
    bool _isConfirming = false;
    bool _isProcessComplete = false;

    // Mostrar el diálogo de confirmación
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmación de Separación'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mensaje de proceso completo (sólo se muestra al finalizar)
                    if (_isProcessComplete) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "Proceso finalizado correctamente",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Regresando a la pantalla principal...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Contenido normal (se oculta durante la confirmación)
                    if (!_isProcessComplete) ...[
                      // Información del operador
                      if (widget.operador != null) ...[
                        const Text('Operador de separación:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.operador!,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                      ],

                      // Información de la revisión
                      Row(
                        children: [
                          Text(
                              'Número de EPCs escaneados: ${allScannedEpcs.length}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showFullList = !_showFullList;
                              });
                            },
                            child: Text(_showFullList
                                ? 'Mostrar menos'
                                : 'Mostrar todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Alerta de advertencia si no hay EPCs escaneados
                      if (allScannedEpcs.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "No hay EPCs escaneados. Solo puedes continuar si seleccionas Rechazado.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Lista de trazabilidades (solo si hay EPCs escaneados)
                      if (allScannedEpcs.isNotEmpty) ...[
                        Container(
                          height: _showFullList ? 200 : 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lista de Trazabilidades:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                ...allScannedEpcs.map((epc) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(epc,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 14,
                                          )),
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Selección de estado con RadioButtons para mayor confiabilidad
                      const Text('Seleccione el estado final:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Opción 1: Material Separado
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                _dialogTempSelectedStatus == "Material Separado"
                                    ? Colors.green
                                    : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: RadioListTile<String>(
                          title: const Text('Material Separado',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          value: "Material Separado",
                          groupValue: _dialogTempSelectedStatus,
                          activeColor: Colors.green,
                          onChanged: (value) {
                            setState(() {
                              _dialogTempSelectedStatus = value!;
                              print(
                                  "DEBUG: Seleccionado $_dialogTempSelectedStatus");
                            });
                          },
                          secondary: Icon(
                            Icons.check_circle,
                            color:
                                _dialogTempSelectedStatus == "Material Separado"
                                    ? Colors.green
                                    : Colors.grey,
                            size: 28,
                          ),
                        ),
                      ),

                      // Opción 2: Rechazado
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _dialogTempSelectedStatus ==
                                    "Rechazado en Separación de Producto"
                                ? Colors.red
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: RadioListTile<String>(
                          title: const Text('Rechazado en la Separación',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          value: "Rechazado en Separación de Producto",
                          groupValue: _dialogTempSelectedStatus,
                          activeColor: Colors.red,
                          onChanged: (value) {
                            setState(() {
                              _dialogTempSelectedStatus = value!;
                              print(
                                  "DEBUG: Seleccionado $_dialogTempSelectedStatus");
                            });
                          },
                          secondary: Icon(
                            Icons.cancel,
                            color: _dialogTempSelectedStatus ==
                                    "Rechazado en Separación de Producto"
                                ? Colors.red
                                : Colors.grey,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!_isProcessComplete && !_isConfirming) ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Verificar si es posible continuar
                      bool puedeAvanzar = allScannedEpcs.isNotEmpty ||
                          _dialogTempSelectedStatus ==
                              "Rechazado en Separación de Producto";

                      if (!puedeAvanzar) {
                        // Mostrar mensaje de error
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'No es posible completar la separación sin EPCs escaneados. Seleccione "Rechazado" si desea cancelar el proceso.'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 5),
                          ),
                        );
                        return;
                      }

                      // Actualizar estado a confirmando
                      setState(() {
                        _isConfirming = true;
                      });

                      // Actualizar el estado seleccionado en el componente principal
                      print(
                          "DEBUG: Actualizando estado global de $selectedStatus a $_dialogTempSelectedStatus");
                      this.setState(() {
                        selectedStatus = _dialogTempSelectedStatus;
                      });

                      try {
                        // Procesar la solicitud con la lista de EPCs
                        await _processUpdateRequest(
                            allScannedEpcs, dialogContext);

                        // Si llegamos aquí, el proceso fue exitoso
                        if (context.mounted) {
                          setState(() {
                            _isConfirming = false;
                            _isProcessComplete = true;
                          });

                          // Programar cierre automático después de mostrar confirmación
                          Future.delayed(Duration(seconds: 2), () {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (context.mounted) {
                              Navigator.of(context)
                                  .pop(); // Regresar a LogisticaListScreen
                            }
                          });
                        }
                      } catch (e) {
                        // Si hay un error, actualizar la interfaz
                        if (context.mounted) {
                          setState(() {
                            _isConfirming = false;
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _dialogTempSelectedStatus == "Material Separado"
                              ? Colors.green
                              : Colors.red,
                    ),
                    child: _isConfirming
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Confirmar',
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // Método para actualizar el estado de la logística
  Future<void> _processUpdateRequest(
      List<String> allScannedEpcs, BuildContext dialogContext) async {
    // Verificar que haya un ID de revisión
    if (widget.revisionId == null || widget.revisionId == 0) {
      // Intentar usar el ID de separación si está disponible
      final revisionIdToUse = widget.separacionId ?? 0;

      print(
          "⚠️ No se encontró ID de revisión. Intentando usar ID de separación: $revisionIdToUse");

      if (revisionIdToUse == 0) {
        _showErrorSnackBar('No hay ID de revisión para actualizar');
        throw Exception('No hay ID de revisión para actualizar');
      }

      // Continuar con el ID de separación como ID de revisión
      return await _executeUpdate(
          allScannedEpcs, revisionIdToUse, dialogContext);
    } else {
      // Usar el ID de revisión normalmente
      return await _executeUpdate(
          allScannedEpcs, widget.revisionId!, dialogContext);
    }
  }

  Future<void> _executeUpdate(List<String> allScannedEpcs, int revisionId,
      BuildContext dialogContext) async {
    setState(() => isProcessing = true);

    try {
      // Fecha actual para el lastUpdate
      String currentDateTime = DateTime.now().toIso8601String();

      // FLUJO DIFERENTE SEGÚN EL ESTADO SELECCIONADO
      if (selectedStatus == "Rechazado en Separación de Producto") {
        // CASO DE RECHAZO: Se usa un endpoint diferente
        print("🚫 Ejecutando flujo de RECHAZO para logística");

        // 1. Primero actualizamos el estado en el endpoint específico para rechazos
        final statusUpdateUrl =
            'http://172.16.10.31/api/logistics_to_review/${revisionId}/status';

        // Enviar el estado como un string JSON directo
        final statusValue = selectedStatus;

        print("🔗 URL de la petición de cambio de estado: $statusUpdateUrl");
        print("📦 Enviando estado: $statusValue");

        // Enviamos el estado como un string JSON
        final statusResponse = await http
            .put(
              Uri.parse(statusUpdateUrl),
              headers: {'Content-Type': 'application/json'},
              body:
                  '"$statusValue"', // Importante: las comillas externas hacen que sea un string JSON válido
            )
            .timeout(const Duration(seconds: 15));

        print(
            "📫 Respuesta del servidor para cambio de estado (${statusResponse.statusCode}): ${statusResponse.body}");

        if (statusResponse.statusCode != 200 &&
            statusResponse.statusCode != 201) {
          throw Exception(
              'Error al actualizar el estado: ${statusResponse.statusCode} - ${statusResponse.body}');
        }

        // 2. Luego, mostramos un diálogo para capturar el comentario
        if (context.mounted) {
          final comentario = await _showComentarioDialog(dialogContext);

          if (comentario != null) {
            // 3. Enviamos el comentario al segundo endpoint
            final rechazoUrl =
                'http://172.16.10.31/api/RechazoSeparacionMaterial';

            final rechazoData = {
              "id_Revision": revisionId,
              "comentario": comentario
            };

            print("🔗 URL para registro de rechazo: $rechazoUrl");
            print("📦 Payload para rechazo: ${jsonEncode(rechazoData)}");

            final rechazoResponse = await http
                .post(
                  Uri.parse(rechazoUrl),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(rechazoData),
                )
                .timeout(const Duration(seconds: 15));

            print(
                "📫 Respuesta del servidor para rechazo (${rechazoResponse.statusCode}): ${rechazoResponse.body}");

            if (rechazoResponse.statusCode != 200 &&
                rechazoResponse.statusCode != 201) {
              throw Exception(
                  'Error al registrar el rechazo: ${rechazoResponse.statusCode} - ${rechazoResponse.body}');
            }
          } else {
            // El usuario canceló la entrada del comentario
            throw Exception('Operación cancelada por el usuario');
          }
        }
      } else {
        // CASO NORMAL: Material Separado - Usamos el endpoint original con la lista de EPCs
        final Map<String, dynamic> updateData = {
          "id": widget.separacionId,
          "id_Revision": revisionId,
          "no_Logistica": widget.noLogistica,
          "cliente": logisticaDetail?['cliente'] ??
              widget.logisticaCompleta?['cliente'],
          "operador_Separador": widget.operador,
          "estatus": selectedStatus,
          "auxiliarVentas": logisticaDetail?['auxVentas'] ??
              widget.logisticaCompleta?['auxVentas'],
          "epcs": allScannedEpcs,
          "numeroEpcs": allScannedEpcs.length, // Asegurando el envío del conteo
          "lastUpdate": currentDateTime,
          "Lista_Trazabilidades": allScannedEpcs,
          "putLogisticsDto": {}
        };

        final serializedJson = jsonEncode(updateData);
        print("📦 Payload enviado a logistics_to_review: $serializedJson");
        print("🔢 Número de EPCs enviados: ${allScannedEpcs.length}");
        print(
            "🔗 URL de la petición: http://172.16.10.31/api/logistics_to_review/$revisionId");

        final response = await http
            .put(
              Uri.parse(
                  'http://172.16.10.31/api/logistics_to_review/$revisionId'),
              headers: {'Content-Type': 'application/json'},
              body: serializedJson,
            )
            .timeout(const Duration(seconds: 15));

        print(
            "📫 Respuesta del servidor (${response.statusCode}): ${response.body}");

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception(
              'Error en la respuesta: ${response.statusCode} - ${response.body}');
        }
      }

      // Actualización exitosa para ambos flujos
      if (context.mounted) {
        setState(() {
          lastUpdate = currentDateTime;
          isProcessing = false;
        });

        // IMPORTANTE: Limpiar los datos de esta logística específica
        print(
            "🧹 Iniciando limpieza de datos para logística ${widget.noLogistica}");
        MaterialSeparationWidgetState.resetLogisticaData(
            widget.noLogistica.toString());

        // Limpiar los datos locales de cada widget
        widget._materialKeys.forEach((index, key) {
          if (key.currentState != null) {
            key.currentState!.resetLocalData();
            print("🧼 Limpiando datos locales del widget en índice $index");
          }
        });

        print(
            "✅ Limpieza de datos completada para logística ${widget.noLogistica}");

        // Mostrar mensaje de éxito al usuario
        _showSuccessSnackBar('Separación de material procesada correctamente');
      }
    } catch (e) {
      print("❌ Error al actualizar el estado: ${e.toString()}");
      _showErrorSnackBar('Error al actualizar: ${e.toString()}');
      setState(() => isProcessing = false);
      throw e;
    }
  }

// Método para mostrar el diálogo de comentario
  Future<String?> _showComentarioDialog(BuildContext context) {
    final comentarioController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Motivo de Rechazo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Por favor, ingrese un comentario sobre el motivo del rechazo:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: comentarioController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Escriba el motivo del rechazo...',
                  labelText: 'Comentario',
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(null), // Cancelar
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (comentarioController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Debe ingresar un comentario para continuar'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(comentarioController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Confirmar Rechazo',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    const Color baseColor = Color(0xFF85B6C4);
    Color statusColor =
        _getCardColor(logisticaDetail?['semaforo']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                  const Icon(Icons.local_shipping,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Logística ${_safeToString(logisticaDetail?['nO_LOGISTICA'] ?? widget.noLogistica)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white54, thickness: 1, height: 20),
          const SizedBox(height: 10),
          _buildHeaderInfo(
            'Cliente',
            logisticaDetail?['cliente'] ?? widget.logisticaCompleta?['cliente'],
            Icons.person,
          ),
          const SizedBox(height: 10),
          _buildHeaderInfo(
            'Fecha Programada',
            logisticaDetail?['fechaProg']?.toString().split(' ')[0] ??
                widget.logisticaCompleta?['fechaProg']
                    ?.toString()
                    .split(' ')[0],
            Icons.calendar_today,
          ),
          // Mostrar el operador seleccionado si existe
          if (widget.operador != null) ...[
            const SizedBox(height: 10),
            _buildHeaderInfo(
              'Operador',
              widget.operador,
              Icons.person_outline,
            ),
          ],
          // Mostrar el ID de revisión si existe
          if (widget.revisionId != null) ...[
            const SizedBox(height: 10),
            _buildHeaderInfo(
              'ID Revisión',
              widget.revisionId,
              Icons.article_outlined,
            ),
          ],
          // Mostrar la última actualización si existe
          if (lastUpdate != null) ...[
            const SizedBox(height: 10),
            _buildHeaderInfo(
              'Última Actualización',
              lastUpdate,
              Icons.update,
            ),
          ],
          // Mostrar el estado actual
          const SizedBox(height: 10),
          _buildHeaderInfo(
            'Estado',
            selectedStatus,
            Icons.info_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistroItem(dynamic registro, int index) {
    // Asegurarnos de que existe una key para este índice
    if (!widget._materialKeys.containsKey(index)) {
      widget._materialKeys[index] = GlobalKey<MaterialSeparationWidgetState>();
    }

    Color statusColor = _getCardColor(registro['semaforo']?.toString() ?? '');
    String estatus = _safeToString(registro['estatus2']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _safeToString(registro['producto']),
                              style: const TextStyle(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                const SizedBox(height: 10),
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
                            'Comentarios:',
                            registro['coments'],
                            statusColor,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
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
                          const SizedBox(height: 4),
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
                              const SizedBox(width: 6),
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
                const SizedBox(height: 15),
                _buildUbicacionDropdownWithColor(index, statusColor),
              ],
            ),
          ),
          MaterialSeparationWidget(
            key: widget._materialKeys[index],
            registro: registro,
            materialKey: widget._materialKeys[index]!,
            noLogistica: widget.noLogistica, // Pasar el número de logística
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithColor(String label, dynamic value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
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
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              _safeToString(value),
              style: const TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                style: const TextStyle(
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
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogisticaDetail,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQualityReviewModal,
        label: const Text(
          'Finalizar Separación',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.check_circle),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchLogisticaDetail,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: registros.isEmpty
                          ? const Center(
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
