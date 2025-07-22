import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Define a model class for the factura data
class FacturaModel {
  final int factura;
  final String? cliente; // Mantiene nullabilidad

  FacturaModel({
    required this.factura,
    this.cliente,
  });

  factory FacturaModel.fromJson(Map<String, dynamic> json) {
    // Conversión segura para manejar posibles errores de tipos
    int facturaValue;
    try {
      facturaValue = json['factura'] is int
          ? json['factura']
          : int.parse(json['factura'].toString());
    } catch (e) {
      print("Error convirtiendo factura: $e");
      facturaValue = 0; // Valor predeterminado
    }

    // Manejo seguro del valor nullable
    String? clienteValue;
    if (json['cliente'] != null) {
      try {
        clienteValue = json['cliente'].toString();
      } catch (e) {
        print("Error convirtiendo cliente: $e");
        // Dejamos como null en caso de error
      }
}

    return FacturaModel(
      factura: facturaValue,
      cliente: clienteValue,
    );
  }
}

class EvidenciaTraficoView extends StatefulWidget {
  const EvidenciaTraficoView({Key? key}) : super(key: key);

  @override
  _EvidenciaTraficoViewState createState() => _EvidenciaTraficoViewState();
}

class _EvidenciaTraficoViewState extends State<EvidenciaTraficoView> {
  // Mode selector (new record or add photos to existing)
  bool _isAddingPhotosMode = false;

  // Controllers for text fields
  final _folioFacturaController = TextEditingController();
  final _clienteController = TextEditingController();
  final _responsableController = TextEditingController();
  final _comentariosController = TextEditingController();
  //final _dispositivoController = TextEditingController();

  // List to store photos
  final List<File> _photoFiles = [];
  final List<String> _photoFilePaths = [];

  // List to store facturas from API
  List<FacturaModel> _facturas = [];
  FacturaModel? _selectedFactura;
  bool _isLoadingFacturas = false;
  bool _hasFacturasError = false;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // Loading indicator state
  bool _isLoading = false;

  // Color base - usando el verde azulado oscuro específico de la app
  static const Color baseColor = Color.fromRGBO(0, 77, 64, 1);
  static const Color lightBaseColor = Color.fromRGBO(0, 121, 107, 1);
  static const Color backgroundColorLight = Color.fromRGBO(247, 247, 247, 1);
  static const Color baseColorLight = Color.fromRGBO(0, 77, 64, 0.05);
  static const Color baseColorMedium = Color.fromRGBO(0, 77, 64, 0.2);
  static const Color baseColorBorder = Color.fromRGBO(0, 77, 64, 0.3);

  @override
  void initState() {
    super.initState();
    // Fetch facturas when the view is initialized
    _fetchFacturas();
  }

  @override
  void dispose() {
    _folioFacturaController.dispose();
    _clienteController.dispose();
    _responsableController.dispose();
    _comentariosController.dispose();
    //_dispositivoController.dispose();
    super.dispose();
  }

  // Fetch facturas from the API
  Future<void> _fetchFacturas() async {
    setState(() {
      _isLoadingFacturas = true;
      _hasFacturasError = false;
    });

    try {
      final response = await http.get(
        Uri.parse('http://172.16.10.31/api/FacturasList'),
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);

          // Debugging: Imprimir la respuesta en consola para verificar
          print("Respuesta API: ${response.body}");

          setState(() {
            _facturas = data.map((item) {
              try {
                return FacturaModel.fromJson(item);
              } catch (e) {
                // Registrar error específico por cada item
                print("Error al convertir item: $item");
                print("Error detallado: $e");
                throw e; // Re-lanzar para ser capturado por el catch exterior
              }
            }).toList();
            _isLoadingFacturas = false;
          });
        } catch (e) {
          setState(() {
            _isLoadingFacturas = false;
            _hasFacturasError = true;
          });
          _showErrorSnackBar('Error al procesar facturas: $e');
          print("Error completo: $e\nStackTrace: ${StackTrace.current}");
        }
      } else {
        setState(() {
          _isLoadingFacturas = false;
          _hasFacturasError = true;
        });
        _showErrorSnackBar('Error al cargar facturas: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoadingFacturas = false;
        _hasFacturasError = true;
      });
      _showErrorSnackBar('Error al cargar facturas: $e');
    }
  }

  // Handle factura selection
  void _handleFacturaSelection(FacturaModel? factura) {
    setState(() {
      _selectedFactura = factura;
      if (factura != null) {
        _folioFacturaController.text = factura.factura.toString();
        // Manejar caso donde noLogistica puede ser null
        if (factura.cliente != null) {
          _clienteController.text = factura.cliente.toString();
        } else {
          _clienteController.clear();
        }
      } else {
        _folioFacturaController.clear();
        _clienteController.clear();
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        setState(() {
          _photoFiles.add(imageFile);
          _photoFilePaths.add(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error al capturar imagen: $e');
    }
  }

  Future<void> _pickGalleryImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        setState(() {
          _photoFiles.add(imageFile);
          _photoFilePaths.add(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar imagen: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.all(10),
    ));
  }

  Future<void> _submitForm() async {
    // Validar campos
    if (_isAddingPhotosMode) {
      if (_folioFacturaController.text.isEmpty) {
        _showErrorSnackBar('El Folio Factura es requerido para agregar fotos');
        return;
      }
      if (_photoFiles.isEmpty) {
        _showErrorSnackBar('Debe agregar al menos una foto');
        return;
      }
    } else {
      if (_selectedFactura == null) {
        _showErrorSnackBar('Debe seleccionar una factura');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isAddingPhotosMode) {
        // Call API to add photos to existing folio
        await _addPhotosToExistingFolio();
      } else {
        // Call API to create new document
        await _createNewDocument();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAddingPhotosMode
            ? 'Fotos agregadas exitosamente'
            : 'Registro creado exitosamente'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
      ));

      // Clear form if it was successful
      _clearForm();
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addPhotosToExistingFolio() async {
    if (_folioFacturaController.text.isEmpty) {
      throw Exception('Folio Factura es requerido para agregar fotos');
    }

    if (_photoFiles.isEmpty) {
      throw Exception('Se requiere al menos una foto');
    }

    final int folioFactura = int.parse(_folioFacturaController.text);
    final String apiUrl =
        'http://172.16.10.31/api/EvidenciasTrafico/AddPhotos/$folioFactura';

    // Create multipart request
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

    // Add all photo files
    for (int i = 0; i < _photoFiles.length; i++) {
      final file = _photoFiles[i];
      request.files.add(await http.MultipartFile.fromPath('Fotos', file.path));
    }

    // Send the request
    final response = await request.send();

    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      throw Exception(
          'Error al subir fotos: ${response.statusCode} - $responseBody');
    }
  }

  Future<void> _createNewDocument() async {
    // Create multipart request for full form submission
    final apiUrl = 'http://172.16.10.31/api/EvidenciasTraficoV2/create';
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

    // Add text fields - exactamente como se ve en la API
    if (_selectedFactura != null) {
      request.fields['FolioFactura'] = _selectedFactura!.factura.toString();

      // Para no_logistica: usamos el valor del controller (que podría ser ingresado por el usuario)
      // en lugar de usar directamente el valor del modelo que podría ser null
      if (_clienteController.text.isNotEmpty) {
  request.fields['cliente'] = _clienteController.text;
}
    }

    if (_responsableController.text.isNotEmpty) {
      request.fields['Responsable'] = _responsableController.text;
    }

    if (_comentariosController.text.isNotEmpty) {
      request.fields['Comentarios'] = _comentariosController.text;
    }

    // if (_dispositivoController.text.isNotEmpty) {
    //   request.fields['Dispositivo'] = _dispositivoController.text;
    // }
    
    // Siempre enviar un valor fijo para Dispositivo
    request.fields['Dispositivo'] = "RFID-Scanner"; // O cualquier valor fijo que desees

    // Add all photo files
    if (_photoFiles.isNotEmpty) {
      for (int i = 0; i < _photoFiles.length; i++) {
        final file = _photoFiles[i];
        request.files
            .add(await http.MultipartFile.fromPath('Fotos', file.path));
      }
    }

    // Send the request
    final response = await request.send();

    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      throw Exception(
          'Error al crear documento: ${response.statusCode} - $responseBody');
    }
  }

  void _clearForm() {
    _selectedFactura = null;

    if (!_isAddingPhotosMode) {
      _folioFacturaController.clear();
      _clienteController.clear();
      _responsableController.clear();
      _comentariosController.clear();
      //_dispositivoController.clear();
    } else {
      // In add photos mode, only clear photos
      _folioFacturaController.clear();
    }

    setState(() {
      _photoFiles.clear();
      _photoFilePaths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColorLight,
      appBar: AppBar(
        title: Text(
          _isAddingPhotosMode ? 'Agregar Fotos' : 'Evidencias de Tráfico',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: baseColor,
        elevation: 2,
        actions: [
          // Mode switch button
          IconButton(
            icon: Icon(
              _isAddingPhotosMode ? Icons.note_add : Icons.photo_library,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isAddingPhotosMode = !_isAddingPhotosMode;
                _clearForm();
              });
            },
            tooltip: _isAddingPhotosMode
                ? 'Cambiar a modo nueva evidencia'
                : 'Cambiar a modo agregar fotos',
          )
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              color: backgroundColorLight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informational card about current mode
                      _buildInfoCard(),

                      SizedBox(height: 16),

                      // Fields container
                      _buildFieldsContainer(),

                      SizedBox(height: 20),

                      // Photos container
                      _buildPhotosContainer(),

                      SizedBox(height: 24),

                      // Submit Button
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
            // Loading indicator overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColorMedium,
            baseColorLight,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: baseColorBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: baseColorMedium,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: baseColor,
                  width: 1,
                ),
              ),
              child: Icon(
                _isAddingPhotosMode ? Icons.photo_library : Icons.assignment,
                color: baseColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAddingPhotosMode
                        ? 'Agregar Fotos a Registro Existente'
                        : 'Crear Nuevo Registro de Evidencia',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    _isAddingPhotosMode
                        ? 'Ingrese el Folio Factura y seleccione las fotos a agregar.'
                        : 'Complete el formulario y suba las fotos necesarias.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: baseColorBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_document,
                    color: baseColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Información del Documento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.grey[200]),

            // FolioFactura Field (always visible)
            _buildFieldLabel(
              'FolioFactura',
              '* requerido',
              Icons.format_list_numbered,
            ),

            // Modified to use a dropdown instead of a text field for factura
            _isAddingPhotosMode
                ? _buildTextField(
                    controller: _folioFacturaController,
                    hintText: 'Ingrese el número de folio factura',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  )
                : _buildFacturaDropdown(),

            // Remaining fields only visible in full form mode
            if (!_isAddingPhotosMode) ...[
              SizedBox(height: 16),

              // no_logistica Field (ahora editable si viene null en la factura)
              _buildFieldLabel(
                'Cliente',
                '',
                Icons.local_shipping,
              ),
              _buildTextField(
                controller: _clienteController,
                hintText: _selectedFactura?.cliente == null
                    ? 'Ingrese el nombre del cliente'
                    : 'Nombre del cliente',
                keyboardType: TextInputType.text, // Changed from number to text
                inputFormatters: [], // Remove FilteringTextInputFormatter.digitsOnly
                readOnly: false,
              ),

              SizedBox(height: 16),

              // Responsable Field
              _buildFieldLabel(
                'Responsable',
                '',
                Icons.person,
              ),
              _buildTextField(
                controller: _responsableController,
                hintText: 'Nombre del responsable',
              ),

              SizedBox(height: 16),

              // Comentarios Field
              _buildFieldLabel(
                'Comentarios',
                '',
                Icons.comment,
              ),
              _buildTextField(
                controller: _comentariosController,
                hintText: 'Ingrese comentarios adicionales',
                maxLines: 3,
              ),

              SizedBox(height: 16),

              // Dispositivo Field
              // _buildFieldLabel(
              //   'Dispositivo',
              //   '',
              //   Icons.devices,
              // ),
              // _buildTextField(
              //   controller: _dispositivoController,
              //   hintText: 'Nombre o ID del dispositivo',
              // ),
            ],
          ],
        ),
      ),
    );
  }

  // New widget for the facturas dropdown - version simplificada
  Widget _buildFacturaDropdown() {
    if (_isLoadingFacturas) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(baseColor),
              ),
              SizedBox(height: 10),
              Text(
                'Cargando facturas...',
                style: TextStyle(color: baseColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasFacturasError) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: baseColorLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Error al cargar facturas',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _fetchFacturas,
              child: Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: baseColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: baseColorLight,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: baseColorBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FacturaModel>(
          isExpanded: true,
          hint: Text(
            'Seleccione una factura',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          value: _selectedFactura,
          iconEnabledColor: baseColor,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[800],
          ),
          items: _facturas.map((FacturaModel factura) {
            return DropdownMenuItem<FacturaModel>(
              value: factura,
              child: Text(
                'Factura: ${factura.factura}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (FacturaModel? newValue) {
            _handleFacturaSelection(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildPhotosContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: baseColorBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    color: baseColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Fotos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                  if (_isAddingPhotosMode) ...[
                    SizedBox(width: 8),
                    Text(
                      '* requerido',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(color: Colors.grey[200]),
            SizedBox(height: 8),

            _buildPhotoGrid(),
            SizedBox(height: 20),
            _buildPhotoButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: (_photoFiles.isEmpty && _isAddingPhotosMode) ||
                (!_isAddingPhotosMode && _selectedFactura == null)
            ? null
            : _submitForm,
        icon: Icon(_isAddingPhotosMode ? Icons.upload_file : Icons.save_alt),
        label: Text(
          _isAddingPhotosMode ? 'SUBIR FOTOS' : 'GUARDAR EVIDENCIA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: baseColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, [String? required, IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: baseColorMedium,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: baseColor,
                size: 18,
              ),
            ),
            SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (required != null && required.isNotEmpty) ...[
            SizedBox(width: 8),
            Text(
              required,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey[100] : baseColorLight,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: baseColorBorder),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
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
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[800],
        ),
        cursorColor: baseColor,
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (_photoFiles.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: baseColorLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: baseColorBorder,
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate,
                size: 48,
                color: baseColor,
              ),
              SizedBox(height: 12),
              Text(
                'Agregar fotos',
                style: TextStyle(
                  color: baseColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Toma una foto o selecciona de la galería',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_photoFiles.length} ${_photoFiles.length == 1 ? 'foto' : 'fotos'} seleccionadas',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _photoFiles.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  // Photo thumbnail with better styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _photoFiles[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Delete button overlay with improved styling
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _photoFiles.removeAt(index);
                          _photoFilePaths.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 0,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.red[700],
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  // Add a subtle photo overlay gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Show number indicator
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );
    }
  }

  Widget _buildPhotoButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tomar Foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: baseColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickGalleryImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('Galería'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
