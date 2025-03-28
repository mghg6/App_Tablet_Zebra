import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class RevisionUnidadesView extends StatefulWidget {
  const RevisionUnidadesView({Key? key}) : super(key: key);

  @override
  _RevisionUnidadesViewState createState() => _RevisionUnidadesViewState();
}

class _RevisionUnidadesViewState extends State<RevisionUnidadesView> {
  // Controllers for text fields
  final _proveedorController = TextEditingController();
  final _operadorController = TextEditingController();
  final _placasController = TextEditingController();
  final _horaController = TextEditingController();
  final _fechaController = TextEditingController();
  final _viajeController = TextEditingController();
  final _clienteController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _revisorController = TextEditingController();
  final _logisticasController = TextEditingController();
  final _observacionesRevisionController =
      TextEditingController(); // Nuevo campo

  // Estado aprobado/rechazado
  String _status =
      'Activo'; // Valores posibles: 'Activo', 'Aprobado', 'Rechazado'

  // Map to store checkbox values
  final Map<String, bool?> _documentacion = {
    'Licencia vigente': null,
    'Seguro de la unidad': null,
    'Seguro del chofer': null,
    'Tarjeta de circulación': null,
    'Verificación fisico mecánica': null,
    'Verificación de emisiones contaminantes': null,
    'Certificado de fumigación': null,
    'Factura': null,
    'Certificado de calidad': null,
  };

  final Map<String, bool?> _aspecto = {
    'Limpieza': null,
    'Sin restos de otro(s) material(es)': null,
    'Sin olores extraños': null,
    'Ausencia de plagas': null,
  };

  // Observaciones para cada campo
  final Map<String, TextEditingController> _observacionesDocumentacion = {};
  final Map<String, TextEditingController> _observacionesAspecto = {};

  // Map para almacenar las fotos de evidencia para cada ítem
  final Map<String, List<File>> _fotosDocumentacion = {};
  final Map<String, List<File>> _fotosAspecto = {};

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // Loading indicator state
  bool _isLoading = false;

  // Color base - updated to the specified teal dark green
  static const Color baseColor =
      Color.fromRGBO(0, 77, 64, 1); // Primary color as requested
  static const Color lightBaseColor =
      Color.fromRGBO(0, 105, 92, 1); // Lighter version
  static const Color backgroundColorLight = Color.fromRGBO(
      245, 250, 248, 1); // Light background with slight teal tint
  static const Color baseColorLight =
      Color.fromRGBO(0, 77, 64, 0.05); // Very light teal for backgrounds
  static const Color baseColorMedium =
      Color.fromRGBO(0, 77, 64, 0.15); // Medium teal for indicators
  static const Color baseColorBorder =
      Color.fromRGBO(0, 77, 64, 0.25); // Border color
  static const Color accentColor =
      Color.fromRGBO(255, 193, 7, 1); // Amber accent for highlights

  @override
  void initState() {
    super.initState();

    // Inicializar la fecha con la fecha actual
    _fechaController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());

    // Inicializar la hora con la hora actual
    _horaController.text = DateFormat('HH:mm').format(DateTime.now());

    // Inicializar controllers para observaciones y fotos
    for (String key in _documentacion.keys) {
      _observacionesDocumentacion[key] = TextEditingController();
      _fotosDocumentacion[key] = [];
    }

    for (String key in _aspecto.keys) {
      _observacionesAspecto[key] = TextEditingController();
      _fotosAspecto[key] = [];
    }
  }

  @override
  void dispose() {
    _proveedorController.dispose();
    _operadorController.dispose();
    _placasController.dispose();
    _horaController.dispose();
    _fechaController.dispose();
    _viajeController.dispose();
    _clienteController.dispose();
    _observacionesController.dispose();
    _revisorController.dispose();
    _logisticasController.dispose();
    _observacionesRevisionController.dispose(); // Nuevo campo

    // Dispose de los controllers de observaciones
    for (var controller in _observacionesDocumentacion.values) {
      controller.dispose();
    }
    for (var controller in _observacionesAspecto.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 4),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: Colors.green[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 4),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ));
  }

  Future<void> _pickImage(String categoria, String item) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        setState(() {
          if (categoria == 'documentacion') {
            _fotosDocumentacion[item]!.add(imageFile);
          } else if (categoria == 'aspecto') {
            _fotosAspecto[item]!.add(imageFile);
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error al capturar imagen: $e');
    }
  }

  Future<void> _pickGalleryImage(String categoria, String item) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        setState(() {
          if (categoria == 'documentacion') {
            _fotosDocumentacion[item]!.add(imageFile);
          } else if (categoria == 'aspecto') {
            _fotosAspecto[item]!.add(imageFile);
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar imagen: $e');
    }
  }

  void _deleteImage(String categoria, String item, int index) {
    setState(() {
      if (categoria == 'documentacion') {
        _fotosDocumentacion[item]!.removeAt(index);
      } else if (categoria == 'aspecto') {
        _fotosAspecto[item]!.removeAt(index);
      }
    });
  }

  // Helper method to convert UI field names to API field names
  String _getApiFieldName(String uiFieldName) {
    switch (uiFieldName) {
      // Documentacion fields
      case 'Licencia vigente':
        return 'licencia_vigente';
      case 'Seguro de la unidad':
        return 'seguro_unidad';
      case 'Seguro del chofer':
        return 'seguro_chofer';
      case 'Tarjeta de circulación':
        return 'tarjeta_circulacion';
      case 'Verificación fisico mecánica':
        return 'verificacion_fisico_mecanica';
      case 'Verificación de emisiones contaminantes':
        return 'verificacion_emisiones_contaminantes';
      case 'Certificado de fumigación':
        return 'certificado_fumigacion';
      case 'Factura':
        return 'factura';
      case 'Certificado de calidad':
        return 'certificado_calidad';

      // Aspecto fields
      case 'Limpieza':
        return 'limpieza';
      case 'Sin restos de otro(s) material(es)':
        return 'sin_restos_de_materiales';
      case 'Sin olores extraños':
        return 'sin_olores_extranos';
      case 'Ausencia de plagas':
        return 'ausencia_de_plagas';

      default:
        return '';
    }
  }

  Future<void> _submitForm() async {
    // Validación básica
    if (_proveedorController.text.isEmpty ||
        _operadorController.text.isEmpty ||
        _placasController.text.isEmpty ||
        _fechaController.text.isEmpty) {
      _showErrorSnackBar('Por favor complete los campos obligatorios');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Recopilamos todas las observaciones en un solo texto
      String allObservations = _observacionesController.text.isNotEmpty
          ? _observacionesController.text + "\n\n"
          : "";

      // Añadimos observaciones de documentación
      bool hasDocObservations = false;
      String docObservations = "DOCUMENTACIÓN:\n";
      for (String key in _documentacion.keys) {
        if (_observacionesDocumentacion[key]!.text.isNotEmpty) {
          docObservations +=
              "- $key: ${_observacionesDocumentacion[key]!.text}\n";
          hasDocObservations = true;
        }
      }
      if (hasDocObservations) {
        allObservations += docObservations + "\n";
      }

      // Añadimos observaciones de aspecto
      bool hasAspectoObservations = false;
      String aspectoObservations = "ASPECTO:\n";
      for (String key in _aspecto.keys) {
        if (_observacionesAspecto[key]!.text.isNotEmpty) {
          aspectoObservations +=
              "- $key: ${_observacionesAspecto[key]!.text}\n";
          hasAspectoObservations = true;
        }
      }
      if (hasAspectoObservations) {
        allObservations += aspectoObservations;
      }

      // Create multipart request for full form submission
      final apiUrl = 'http://172.16.10.31/api/UnidadCarga/create';
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add text fields - exactamente como se ve en la API
      request.fields['proveedor_unidad'] = _proveedorController.text;
      request.fields['operador_unidad'] = _operadorController.text;
      request.fields['placas_unidad'] = _placasController.text;
      request.fields['fecha_carga'] = _fechaController.text;
      request.fields['viaje'] = _viajeController.text;
      request.fields['cliente'] = _clienteController.text;
      request.fields['observaciones_unidad'] = allObservations;
      request.fields['operador_revision'] = _revisorController.text;
      request.fields['logisticas'] = _logisticasController.text;
      request.fields['observaciones_revision'] =
          _observacionesRevisionController.text;
      request.fields['status'] = _status;

      // Add boolean fields from documentacion
      for (String key in _documentacion.keys) {
        String fieldName = _getApiFieldName(key);
        if (fieldName.isNotEmpty && _documentacion[key] != null) {
          request.fields[fieldName] =
              _documentacion[key] == true ? 'true' : 'false';
        }
      }

      // Add boolean fields from aspecto
      for (String key in _aspecto.keys) {
        String fieldName = _getApiFieldName(key);
        if (fieldName.isNotEmpty && _aspecto[key] != null) {
          request.fields[fieldName] = _aspecto[key] == true ? 'true' : 'false';
        }
      }

      // Add all photo files
      List<File> allPhotos = [];

      // Collect all photos from documentacion
      for (String key in _fotosDocumentacion.keys) {
        allPhotos.addAll(_fotosDocumentacion[key] ?? []);
      }

      // Collect all photos from aspecto
      for (String key in _fotosAspecto.keys) {
        allPhotos.addAll(_fotosAspecto[key] ?? []);
      }

      // Añadir las fotos al request - cada foto en su propio campo 'fotos'
      for (int i = 0; i < allPhotos.length; i++) {
        final file = allPhotos[i];
        request.files
            .add(await http.MultipartFile.fromPath('fotos', file.path));
      }

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('Formulario enviado con éxito');
        _clearForm();
      } else {
        _showErrorSnackBar(
            'Error al enviar el formulario: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      _showErrorSnackBar('Error al enviar el formulario: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _proveedorController.clear();
    _operadorController.clear();
    _placasController.clear();
    _horaController.text = DateFormat('HH:mm').format(DateTime.now());
    _fechaController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _viajeController.clear();
    _clienteController.clear();
    _observacionesController.clear();
    _revisorController.clear();
    _logisticasController.clear();
    _observacionesRevisionController.clear();

    setState(() {
      _status = 'Activo'; // Resetear a valor predeterminado

      for (String key in _documentacion.keys) {
        _documentacion[key] = null;
        _observacionesDocumentacion[key]?.clear();
        _fotosDocumentacion[key]!.clear();
      }

      for (String key in _aspecto.keys) {
        _aspecto[key] = null;
        _observacionesAspecto[key]?.clear();
        _fotosAspecto[key]!.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColorLight,
      body: SafeArea(
        child: Stack(
          children: [
            // Header decoration
            Container(
              height: 30,
              width: double.infinity,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: backgroundColorLight,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado con fecha y revisión
                      _buildHeaderInfo(),

                      SizedBox(height: 16),

                      // Fecha de embarque
                      _buildEmbarqueInfo(),

                      SizedBox(height: 20),

                      // Datos de la unidad
                      _buildDatosUnidad(),

                      SizedBox(height: 20),

                      // Evaluación: Documentación
                      _buildDocumentacionSection(),

                      SizedBox(height: 20),

                      // Evaluación: Aspecto
                      _buildAspectoSection(),

                      SizedBox(height: 20),

                      // Viaje y Cliente
                      _buildViajeClienteSection(),

                      SizedBox(height: 20),

                      // Logísticas
                      _buildLogisticasSection(),

                      SizedBox(height: 20),

                      // Estado de revisión y observaciones de revisión
                      _buildStatusSection(),

                      SizedBox(height: 20),

                      // Observaciones generales
                      _buildObservacionesSection(),

                      SizedBox(height: 20),

                      // Persona que revisa
                      _buildRevisorSection(),

                      SizedBox(height: 30),

                      // Botón de enviar
                      _buildSubmitButton(),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            // Loading indicator overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                          strokeWidth: 4,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Guardando revisión...',
                          style: TextStyle(
                            color: baseColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.article_rounded, color: baseColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Revisión: 01',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: baseColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: baseColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Fecha: ${DateFormat('dd-MM-yy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: baseColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmbarqueInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(
                'Fecha de embarque:', Icons.calendar_today_rounded),
            SizedBox(height: 12),
            _buildTextField(
              controller: _fechaController,
              hintText: 'DD-MM-YYYY',
              readOnly: true,
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(Duration(days: 30)),
                  lastDate: DateTime.now().add(Duration(days: 30)),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: ColorScheme.light(
                          primary: baseColor,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black,
                        ),
                        dialogBackgroundColor: Colors.white,
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _fechaController.text =
                        DateFormat('dd-MM-yyyy').format(picked);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosUnidad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Datos de la unidad',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proveedor
                _buildFieldLabel('Proveedor unidad:', Icons.business_rounded),
                SizedBox(height: 12),
                _buildTextField(
                  controller: _proveedorController,
                  hintText: 'Ingrese nombre del proveedor',
                ),
                SizedBox(height: 20),

                // Operador
                _buildFieldLabel('Nombre el operador:', Icons.person_rounded),
                SizedBox(height: 12),
                _buildTextField(
                  controller: _operadorController,
                  hintText: 'Ingrese nombre del operador',
                ),
                SizedBox(height: 20),

                // Placas y Hora (en fila)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Placas de la unidad:',
                              Icons.directions_car_rounded),
                          SizedBox(height: 12),
                          _buildTextField(
                            controller: _placasController,
                            hintText: 'Ingrese placas',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel(
                              'Hora de carga:', Icons.access_time_rounded),
                          SizedBox(height: 12),
                          _buildTextField(
                            controller: _horaController,
                            hintText: 'HH:MM',
                            readOnly: true,
                            onTap: () async {
                              FocusScope.of(context).requestFocus(FocusNode());
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: baseColor,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                      dialogBackgroundColor: Colors.white,
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _horaController.text =
                                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentacionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Icon(Icons.description_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Documentación',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        'Cumple',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'No cumple',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Text(
                      'Observaciones',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _documentacion.length,
            itemBuilder: (context, index) {
              String key = _documentacion.keys.elementAt(index);
              return _buildCheckboxRow(
                title: key,
                value: _documentacion[key],
                onChangedTrue: (value) {
                  setState(() {
                    _documentacion[key] = true;
                  });
                },
                onChangedFalse: (value) {
                  setState(() {
                    _documentacion[key] = false;
                  });
                },
                observacionesController: _observacionesDocumentacion[key]!,
                categoria: 'documentacion',
                item: key,
                fotos: _fotosDocumentacion[key]!,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAspectoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Aspecto',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        'Cumple',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'No cumple',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Text(
                      'Observaciones',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _aspecto.length,
            itemBuilder: (context, index) {
              String key = _aspecto.keys.elementAt(index);
              return _buildCheckboxRow(
                title: key,
                value: _aspecto[key],
                onChangedTrue: (value) {
                  setState(() {
                    _aspecto[key] = true;
                  });
                },
                onChangedFalse: (value) {
                  setState(() {
                    _aspecto[key] = false;
                  });
                },
                observacionesController: _observacionesAspecto[key]!,
                categoria: 'aspecto',
                item: key,
                fotos: _fotosAspecto[key]!,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViajeClienteSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: lightBaseColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Viaje',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildTextField(
                    controller: _viajeController,
                    hintText: 'Número de viaje',
                    prefixIcon: Icons.numbers_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: lightBaseColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Cliente',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildTextField(
                    controller: _clienteController,
                    hintText: 'Nombre del cliente',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogisticasSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: lightBaseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Logísticas',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información de logística:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                _buildTextField(
                  controller: _logisticasController,
                  hintText: 'Ingrese información de logística',
                  prefixIcon: Icons.inventory_2_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_turned_in_rounded,
                    color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Estado de la revisión',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleccione el estado de la revisión:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatusRadio('Activo', 'Activo'),
                    SizedBox(width: 20),
                    _buildStatusRadio('Aprobado', 'Aprobado'),
                    SizedBox(width: 20),
                    _buildStatusRadio('Rechazado', 'Rechazado'),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  'Observaciones de la revisión:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                _buildTextField(
                  controller: _observacionesRevisionController,
                  hintText: 'Ingrese observaciones sobre la revisión',
                  maxLines: 3,
                  prefixIcon: Icons.rate_review_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRadio(String title, String value) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _status = value;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _status == value ? baseColorLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _status == value ? baseColor : Colors.grey[400]!,
              width: _status == value ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: _status,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _status = newValue;
                    });
                  }
                },
                activeColor: baseColor,
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _status == value ? FontWeight.bold : FontWeight.normal,
                    color: _status == value ? baseColor : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObservacionesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.comment_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Observaciones',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildTextField(
              controller: _observacionesController,
              hintText: 'Ingrese observaciones generales',
              maxLines: 3,
              prefixIcon: Icons.note_alt_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisorSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: lightBaseColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_search_rounded,
                    color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'Revisor',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nombre de la persona que revisa la unidad:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                _buildTextField(
                  controller: _revisorController,
                  hintText: 'Ingrese nombre del revisor',
                  prefixIcon: Icons.badge_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [baseColor, Color.fromRGBO(0, 105, 92, 1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _submitForm,
        icon: Icon(
          Icons.save_rounded,
          size: 24,
        ),
        label: Text(
          'GUARDAR REVISIÓN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, [IconData? icon]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColorMedium,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: baseColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: baseColorLight,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: baseColorBorder),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(
              color: baseColor,
              width: 1.5,
            ),
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: baseColor.withOpacity(0.7), size: 20)
              : null,
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[800],
        ),
        cursorColor: baseColor,
        readOnly: readOnly,
        onTap: onTap,
      ),
    );
  }

  Widget _buildCheckboxRow({
    required String title,
    required bool? value,
    required ValueChanged<bool?>? onChangedTrue,
    required ValueChanged<bool?>? onChangedFalse,
    required TextEditingController observacionesController,
    required String categoria,
    required String item,
    required List<File> fotos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Título
              Expanded(
                flex: 3,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),

              // Checkbox para "Cumple"
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: value == true
                            ? Colors.green[700]!
                            : Colors.grey[400]!,
                        width: value == true ? 1.5 : 1,
                      ),
                      color:
                          value == true ? Colors.green[50] : Colors.transparent,
                    ),
                    child: Checkbox(
                      value: value == true,
                      onChanged: onChangedTrue,
                      activeColor: Colors.green[700],
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),

              // Checkbox para "No cumple"
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: value == false
                            ? Colors.red[700]!
                            : Colors.grey[400]!,
                        width: value == false ? 1.5 : 1,
                      ),
                      color:
                          value == false ? Colors.red[50] : Colors.transparent,
                    ),
                    child: Checkbox(
                      value: value == false,
                      onChanged: onChangedFalse,
                      activeColor: Colors.red[700],
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),

              // Campo de observaciones
              Expanded(
                flex: 4,
                child: TextField(
                  controller: observacionesController,
                  decoration: InputDecoration(
                    hintText: 'Observaciones',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: baseColorBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: baseColorBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: baseColor, width: 1.5),
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ), // Mostrar fotos si hay
        if (fotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_library_rounded,
                        size: 18, color: baseColor),
                    SizedBox(width: 8),
                    Text(
                      'Evidencias fotográficas (${fotos.length}):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: baseColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: fotos.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 12),
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: baseColorBorder, width: 1.5),
                              image: DecorationImage(
                                image: FileImage(fotos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 18,
                            child: InkWell(
                              onTap: () => _deleteImage(categoria, item, index),
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Botones para agregar fotos
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(categoria, item),
                  icon: Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    'Tomar foto',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: baseColor,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickGalleryImage(categoria, item),
                  icon: Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    'Galería',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: baseColor,
                    side: BorderSide(color: baseColor, width: 1.5),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }
}
