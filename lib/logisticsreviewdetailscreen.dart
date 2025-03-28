import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http_parser/http_parser.dart';

// Pantalla de vista previa de imagen (sin cambios)
// Pantalla de vista previa de imagen
class FullScreenImageView extends StatefulWidget {
  final File imageFile;
  final String title;

  const FullScreenImageView({
    Key? key, // Añadido el parámetro key para el constructor
    required this.imageFile,
    this.title = 'Vista previa',
  }) : super(key: key);

  @override
  _FullScreenImageViewState createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  final double _minScale = 0.5;
  final double _maxScale = 4.0;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Método para restablecer la animación
  void _resetAnimation() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward(from: 0);
  }

  // Método para manejar doble tap con zoom
  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  // Método para manejar doble tap con zoom
  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;

    if (_transformationController.value != Matrix4.identity()) {
      // Si ya está ampliado, reset
      _resetAnimation();
    } else {
      // Si no está ampliado, hacer zoom al punto tocado
      final position = _doubleTapDetails!.localPosition;

      // Traducir al origen, escalar y volver a traducir
      final Matrix4 matrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.5) // Escala fija para el zoom
        ..translate(position.dx, position.dy);

      // Animar hasta la nueva matriz
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: matrix,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));

      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.zoom_out_map),
            onPressed: _resetAnimation,
            tooltip: 'Restablecer zoom',
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onDoubleTapDown: _handleDoubleTapDown,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: _minScale,
            maxScale: _maxScale,
            child: Center(
              child: Hero(
                tag: widget.imageFile.path,
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Modelo para Certificado de Calidad (modificado)
class QualityCertificate {
  String certificateNumber;
  String validator;
  DateTime validationDate;
  String observations;
  List<String> relatedEPCs;

  QualityCertificate({
    this.certificateNumber = "POR SUBIR",
    this.validator = "Sistema",
    required this.validationDate,
    this.observations = 'Certificado pendiente de subir',
    required this.relatedEPCs,
  });

  Map<String, dynamic> toJson() => {
        'certificateNumber': certificateNumber,
        'validator': validator,
        'validationDate': validationDate.toIso8601String(),
        'observations': observations,
        'relatedEPCs': relatedEPCs,
      };
  Map<String, bool> epcReviewedStatus = {};
}

class ReviewPoint {
  bool isApproved;
  String? comment;
  File? photo;

  ReviewPoint({
    this.isApproved = true,
    this.comment,
    this.photo,
  });
}

class LogisticsReviewDetailScreen extends StatefulWidget {
  final int reviewId;
  final String previousStatus;

  const LogisticsReviewDetailScreen({
    Key? key,
    required this.reviewId,
    this.previousStatus = 'Material Separado',
  }) : super(key: key);

  @override
  _LogisticsReviewDetailScreenState createState() =>
      _LogisticsReviewDetailScreenState();
}

class _LogisticsReviewDetailScreenState
    extends State<LogisticsReviewDetailScreen> with WidgetsBindingObserver {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detailData;
  Map<String, Map<String, ReviewPoint>> reviewStates = {};
  Map<String, QualityCertificate> certificates = {};
  final ImagePicker _imagePicker = ImagePicker();
  bool hasUnsavedChanges = false;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
// Agregar una nueva propiedad a la clase _LogisticsReviewDetailScreenState
  Map<String, bool> epcReviewedStatus = {};
  // Colores personalizados mejorados
  final Color primaryColor = const Color(0xFF2C3E50);
  final Color accentColor = const Color(0xFF3498DB);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color cardColor = Colors.white;
  final Color successColor = const Color(0xFF2ECC71);
  final Color warningColor = const Color(0xFFF1C40F);
  final Color errorColor = const Color(0xFFE74C3C);

  // Categorías de revisión
  final Map<String, List<String>> reviewCategories = {
    'Estado Físico': [
      'Tarima en buen estado',
      'Empaque sin daños',
      'Producto limpio',
      'Sin deformaciones',
      'Libre de plaga',
      'Flejado correcto',
    ],
    'Información y Etiquetado': [
      'Etiquetas completas',
      'Códigos de barras legibles',
      'Información visible',
      'Fechas correctas',
      'Lote visible',
    ],
    'Especificaciones': [
      'Peso correcto',
      'Cantidad de piezas correcta',
      'Orden de producción correcta',
      'Unidad de medida correcta',
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Puedes usar esto para gestionar el estado de la cámara cuando la app cambia de estado
    if (state == AppLifecycleState.resumed) {
      // La aplicación se ha reanudado
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= 400) {
      if (!_showBackToTop) setState(() => _showBackToTop = true);
    } else {
      if (_showBackToTop) setState(() => _showBackToTop = false);
    }
  }

  // Método para mostrar opciones de fuente de imagen
  void _showImageSourceOptions(String trazabilidad, String point) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seleccionar imagen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Opción de cámara
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Cámara',
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage(trazabilidad, point, ImageSource.camera);
                  },
                ),
                // Opción de galería
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Galería',
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage(trazabilidad, point, ImageSource.gallery);
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Widget para opciones de fuente de imagen
  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: accentColor),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para capturar imágenes
  Future<void> _captureImage(
      String trazabilidad, String point, ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null && mounted) {
        setState(() {
          reviewStates[trazabilidad]![point]!.photo = File(photo.path);
          hasUnsavedChanges = true;
        });
        _showCommentDialog(
            trazabilidad, point); // Vuelve a abrir el diálogo con la foto
      } else {
        // Si el usuario canceló la captura, volvemos a abrir el diálogo sin cambios
        _showCommentDialog(trazabilidad, point);
      }
    } catch (e) {
      _showErrorSnackBar('Error al capturar imagen: $e');
      // En caso de error, volvemos a abrir el diálogo
      if (mounted) _showCommentDialog(trazabilidad, point);
    }
  }

  // Método para mostrar imagen en pantalla completa
  void _showFullScreenImage(File imageFile, {String title = ''}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(
          imageFile: imageFile,
          title: title.isNotEmpty ? title : 'Vista previa',
        ),
      ),
    );
  }

  // Método para optimizar y comprimir imágenes
  Future<Uint8List?> _compressImage(File imageFile) async {
    try {
      // Leer la imagen original
      final bytes = await imageFile.readAsBytes();

      // Decodificar para obtener dimensiones
      final decodedImage = await decodeImageFromList(bytes);
      double width = decodedImage.width.toDouble();
      double height = decodedImage.height.toDouble();

      // Establecer dimensión máxima para la compresión
      const double maxDimension = 1200.0;
      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension) / width;
          width = maxDimension;
        } else {
          width = (width * maxDimension) / height;
          height = maxDimension;
        }
      }

      // Crear un directorio temporal si es necesario
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Comprimir la imagen
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 85,
        format: CompressFormat.jpeg,
        minWidth: width.round(),
        minHeight: height.round(),
      );

      if (result != null) {
        // Leer los bytes comprimidos
        final compressedBytes = await result.readAsBytes();

        // Eliminar el archivo temporal
        try {
          await File(targetPath).delete();
        } catch (e) {
          print('Error al eliminar archivo temporal: $e');
        }

        return compressedBytes;
      }

      return bytes; // Si la compresión falla, devolver los bytes originales
    } catch (e) {
      print('Error al comprimir imagen: $e');
      return null;
    }
  }

  // Header mejorado con diseño moderno
  Widget _buildHeaderSection() {
    final encabezado = detailData?['encabezado'];
    if (encabezado == null) return SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Superior con Diseño de Fondo
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        accentColor,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Elementos decorativos
                      Positioned(
                        top: -30,
                        right: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: -40,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // Contenido principal
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Logística',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '#${encabezado['no_Logistica']}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        encabezado['estatus'],
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
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
                ),
                // Tarjetas de Información
                Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              title: 'Cliente',
                              value: encabezado['cliente'],
                              icon: Icons.business,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              title: 'Operador',
                              value: encabezado['operador_Separador'],
                              icon: Icons.person,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              title: 'EPCs Total',
                              value: encabezado['noEPCs'].toString(),
                              icon: Icons.inventory,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              title: 'Última Actualización',
                              value: _formatDateTime(encabezado['lastUpdate']),
                              icon: Icons.update,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Método para construir la tarjeta de EPC
  // Método para construir la tarjeta de EPC
  Widget _buildEPCCard(Map<String, dynamic> epc) {
    final trazabilidad = epc['trazabilidad'].toString();

    // Verificar si esta tarima está marcada como revisada
    bool isMarkedAsReviewed = epcReviewedStatus[trazabilidad] ?? false;

    // Verificar si todos los puntos han sido revisados (aprobados o con comentarios)
    bool allPointsReviewed = reviewStates[trazabilidad]?.values.every((point) =>
            point.isApproved || (!point.isApproved && point.comment != null)) ??
        false;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Indicador de tarima revisada (badge)
          if (isMarkedAsReviewed)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                height: 30,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: successColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: successColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Revisada',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Contenido de la tarjeta de EPC
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMarkedAsReviewed
                      ? successColor.withOpacity(0.1)
                      : warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isMarkedAsReviewed ? Icons.check_circle : Icons.pending,
                  color: isMarkedAsReviewed ? successColor : warningColor,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trazabilidad: ${epc['trazabilidad']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    epc['nombreProducto'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductInfoCard(epc),
                      SizedBox(height: 24),
                      Text(
                        'Puntos de Revisión',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      ...reviewCategories.entries.map(
                        (category) => _buildReviewCategory(
                          category.key,
                          category.value,
                          trazabilidad,
                        ),
                      ),

                      // Botón para marcar la tarima como revisada
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isMarkedAsReviewed
                                ? Icons.verified_user
                                : Icons.check_circle_outline,
                            color: Colors.white,
                          ),
                          label: Text(
                            isMarkedAsReviewed
                                ? 'TARIMA REVISADA'
                                : 'MARCAR COMO REVISADA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMarkedAsReviewed
                                ? successColor
                                : (allPointsReviewed
                                    ? Colors.blue
                                    : Colors.grey),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: allPointsReviewed
                              ? () {
                                  setState(() {
                                    // Alternar el estado de revisado
                                    epcReviewedStatus[trazabilidad] =
                                        !isMarkedAsReviewed;
                                    hasUnsavedChanges = true;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isMarkedAsReviewed
                                          ? 'Tarima marcada como no revisada'
                                          : 'Tarima marcada como revisada'),
                                      backgroundColor: isMarkedAsReviewed
                                          ? Colors.orange
                                          : successColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              : null, // Deshabilitar si no todos los puntos están revisados
                        ),
                      ),

                      // Mensaje si el botón está deshabilitado
                      if (!allPointsReviewed)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Para marcar como revisada, complete todos los puntos de revisión',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir categoría de revisión
  Widget _buildReviewCategory(
      String categoryName, List<String> points, String trazabilidad) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          ...points.map((point) => _buildCheckboxItem(point, trazabilidad)),
        ],
      ),
    );
  }

  // Método para construir el elemento de checkbox con foto
  Widget _buildCheckboxItem(String point, String trazabilidad) {
    final reviewPoint = reviewStates[trazabilidad]![point]!;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Switch(
                  value: reviewPoint.isApproved,
                  onChanged: (value) {
                    setState(() {
                      reviewPoint.isApproved = value;
                      hasUnsavedChanges = true;
                      if (!value) {
                        _showCommentDialog(trazabilidad, point);
                      } else {
                        reviewPoint.comment = null;
                        reviewPoint.photo = null;
                      }
                    });
                  },
                  activeColor: successColor,
                ),
              ],
            ),
            if (!reviewPoint.isApproved && reviewPoint.comment != null) ...[
              Divider(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motivo:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(reviewPoint.comment!),
                      ],
                    ),
                  ),
                  if (reviewPoint.photo == null)
                    IconButton(
                      icon: Icon(Icons.camera_alt, color: accentColor),
                      onPressed: () =>
                          _showImageSourceOptions(trazabilidad, point),
                      tooltip: 'Agregar foto',
                    ),
                ],
              ),
              if (reviewPoint.photo != null) ...[
                SizedBox(height: 8),
                Stack(
                  children: [
                    InkWell(
                      onTap: () => _showFullScreenImage(reviewPoint.photo!),
                      child: Hero(
                        tag: reviewPoint.photo!.path,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            reviewPoint.photo!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            reviewPoint.photo = null;
                            hasUnsavedChanges = true;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Método para construir la tarjeta de información del producto
  Widget _buildProductInfoCard(Map<String, dynamic> epc) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductInfoRow('Clave de Producto', epc['claveProducto']),
          Divider(height: 20),
          _buildProductInfoRow('Peso Neto', '${epc['pesoNeto']}KGM'),
          Divider(height: 20),
          _buildProductInfoRow('Piezas', epc['piezas'].toString()),
          Divider(height: 20),
          _buildProductInfoRow('Orden', epc['orden']),
          Divider(height: 20),
          _buildProductInfoRow('Clave Producto Cliente', epc['itemNumber']),
          Divider(height: 20),
          _buildProductInfoRow('Orden Cliente', epc['inventoryLot']),
          Divider(height: 20),
          _buildProductInfoRow('Cajas por Tarima', epc['shippingUnits']),
          Divider(height: 20),
          _buildProductInfoRow('Piezas por Caja', epc['individualUnits']),
          SizedBox(height: 16),

          // Mostrar mensaje fijo para el certificado
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certificado de Calidad: POR SUBIR',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'El certificado se cargará posteriormente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para construir cada fila de información
  Widget _buildProductInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[900],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Método para formatear fecha y hora
  String _formatDateTime(String dateTimeStr) {
    final date = DateTime.parse(dateTimeStr).toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  // Método para hacer scroll al inicio
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutQuad,
    );
  }

  // Tarjeta de información mejorada
  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar el diálogo de comentarios con la opción de adjuntar fotos
  void _showCommentDialog(String trazabilidad, String point) {
    final reviewPoint = reviewStates[trazabilidad]![point]!;
    final commentController = TextEditingController(text: reviewPoint.comment);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: warningColor),
            SizedBox(width: 8),
            Expanded(
              child: Text('Indicar motivo de no cumplimiento'),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite, // Ancho fijo para el contenido
          constraints: BoxConstraints(
              maxWidth: 400, maxHeight: 500), // Restricciones de tamaño
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point),
                SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '¿Por qué no cumple con este punto?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 16),
                // Botón para adjuntar foto
                OutlinedButton.icon(
                  icon: Icon(Icons.add_a_photo),
                  label: Text(reviewPoint.photo != null
                      ? 'Cambiar foto'
                      : 'Adjuntar foto'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Cierra el diálogo actual
                    _showImageSourceOptions(
                        trazabilidad, point); // Muestra opciones de fuente
                  },
                ),
                if (reviewPoint.photo != null) ...[
                  SizedBox(height: 16),
                  Text('Foto adjunta:'),
                  SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 150,
                      maxWidth: 300,
                    ),
                    child: InkWell(
                      onTap: () => _showFullScreenImage(reviewPoint.photo!),
                      child: Stack(
                        children: [
                          Hero(
                            tag: reviewPoint.photo!.path,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                reviewPoint.photo!,
                                height: 150,
                                width: 300,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  reviewPoint.photo = null;
                                });
                                Navigator.pop(context);
                                _showCommentDialog(trazabilidad, point);
                              },
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                reviewPoint.isApproved = true;
                reviewPoint.comment = null;
                reviewPoint.photo = null;
              });
              Navigator.pop(context);
            },
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Por favor, indica el motivo'),
                    backgroundColor: errorColor,
                  ),
                );
                return;
              }
              setState(() {
                reviewPoint.comment = commentController.text;
                hasUnsavedChanges = true;
              });
              Navigator.pop(context);
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Método para guardar una foto localmente
  Future<String?> _savePhotoLocally({
    required int reviewId,
    required String trazabilidad,
    required String pointName,
    required Uint8List photoData,
  }) async {
    try {
      // Solicitar permisos
      final permissionGranted = await requestStoragePermission();
      if (!permissionGranted) {
        throw Exception('Permisos de almacenamiento denegados');
      }

      // Obtener directorio de aplicación
      final appDir = await getApplicationDocumentsDirectory();
      final reviewDir = Directory('${appDir.path}/reviews/$reviewId');

      // Crear directorio si no existe
      if (!await reviewDir.exists()) {
        await reviewDir.create(recursive: true);
      }

      // Generar un nombre de archivo único basado en trazabilidad y punto
      final String fileName =
          'photo_${trazabilidad.replaceAll(RegExp(r'[^\w]'), '_')}_${pointName.replaceAll(RegExp(r'[^\w]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '${reviewDir.path}/$fileName';

      // Guardar archivo
      final file = File(filePath);
      await file.writeAsBytes(photoData);

      print('Foto guardada localmente en: $filePath');
      return filePath;
    } catch (e) {
      print('Error al guardar foto localmente: $e');
      return null;
    }
  }

  // Método para guardar metadatos de fotos
  Future<void> _savePhotoMetadata(
      int reviewId, List<Map<String, dynamic>> photosData) async {
    try {
      // Obtener directorio de aplicación
      final appDir = await getApplicationDocumentsDirectory();
      final metadataDir = Directory('${appDir.path}/reviews/$reviewId');

      // Crear directorio si no existe
      if (!await metadataDir.exists()) {
        await metadataDir.create(recursive: true);
      }

      // Crear un objeto JSON con los metadatos
      final metadata = {
        'reviewId': reviewId,
        'createdAt': DateTime.now().toIso8601String(),
        'photos': photosData
            .map((photo) => {
                  'trazabilidad': photo['trazabilidad'],
                  'point': photo['point'],
                  'timestamp': photo['timestamp'],
                  'photoPath':
                      'photo_${photo['trazabilidad'].replaceAll(RegExp(r'[^\w]'), '_')}_${photo['point'].replaceAll(RegExp(r'[^\w]'), '_')}_${DateTime.parse(photo['timestamp']).millisecondsSinceEpoch}.jpg',
                })
            .toList(),
      };

      // Guardar archivo JSON con metadatos
      final File metadataFile = File('${metadataDir.path}/metadata.json');
      await metadataFile.writeAsString(jsonEncode(metadata));

      print('Metadatos guardados en: ${metadataFile.path}');
    } catch (e) {
      print('Error al guardar metadatos: $e');
    }
  }

  // Método para solicitar permisos de almacenamiento
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final statusPhotos = await Permission.photos.request();
        return statusPhotos.isGranted;
      }
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  // Función para limpiar archivos temporales
  Future<void> _cleanupTempFiles() async {
    for (var trazabilidadStates in reviewStates.values) {
      for (var reviewPoint in trazabilidadStates.values) {
        if (reviewPoint.photo != null) {
          try {
            await reviewPoint.photo!.delete();
          } catch (e) {
            print('Error deleting temp file: $e');
          }
        }
      }
    }
  }

  // Método mejorado para subir fotos al servidor
  Future<void> _uploadPhotos() async {
    int totalPhotos = 0;
    int uploadedPhotos = 0;

    // Contar el total de fotos a subir
    for (var trazabilidad in reviewStates.keys) {
      for (var point in reviewStates[trazabilidad]!.keys) {
        if (reviewStates[trazabilidad]![point]!.photo != null) {
          totalPhotos++;
        }
      }
    }

    if (totalPhotos == 0) return; // No hay fotos para subir

    // Mostrar indicador de progreso
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              SizedBox(width: 16),
              Text('Guardando fotos (0/$totalPhotos)...'),
            ],
          ),
          duration: Duration(seconds: 30),
          backgroundColor: primaryColor,
        ),
      );
    }

    // Mientras el endpoint no esté disponible, guardaremos las fotos localmente
    final temporaryPhotoData = <Map<String, dynamic>>[];

    // Subir cada foto
    for (var trazabilidad in reviewStates.keys) {
      for (var point in reviewStates[trazabilidad]!.keys) {
        final reviewPoint = reviewStates[trazabilidad]![point]!;
        if (reviewPoint.photo != null) {
          try {
            // Comprimir la imagen
            final photoData = await _compressImage(reviewPoint.photo!);
            if (photoData == null) {
              throw Exception('Error al comprimir la imagen');
            }

            // Guardar información para cuando el endpoint esté disponible
            temporaryPhotoData.add({
              'trazabilidad': trazabilidad,
              'point': point,
              'photoData': photoData,
              'timestamp': DateTime.now().toIso8601String(),
            });

            // Guardar la foto localmente para uso futuro
            await _savePhotoLocally(
              reviewId: widget.reviewId,
              trazabilidad: trazabilidad,
              pointName: point,
              photoData: photoData,
            );

            uploadedPhotos++;

            // Actualizar el indicador de progreso
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        value: uploadedPhotos / totalPhotos,
                      ),
                      SizedBox(width: 16),
                      Text('Guardando fotos ($uploadedPhotos/$totalPhotos)...'),
                    ],
                  ),
                  duration: Duration(seconds: 30),
                  backgroundColor: primaryColor,
                ),
              );
            }
          } catch (e) {
            print('Error al procesar foto para $trazabilidad - $point: $e');
            throw Exception(
                'Error al procesar foto para $trazabilidad - $point: $e');
          }
        }
      }
    }

    // Limpiar notificación cuando termine
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    // Guardar metadatos de las fotos para uso futuro
    if (temporaryPhotoData.isNotEmpty) {
      await _savePhotoMetadata(widget.reviewId, temporaryPhotoData);
    }
  }

  // Función de guardado modificada
  Future<void> _saveReview() async {
    try {
      print('==== INICIANDO PROCESO DE GUARDAR REVISIÓN ====');
      setState(() => isLoading = true);

      // Calcular si hay rechazos en algún punto de la revisión
      print('Verificando si hay rechazos...');
      bool hasRejections = false;
      for (var trazabilidadKey in reviewStates.keys) {
        print('Verificando rechazos para trazabilidad: $trazabilidadKey');
        for (var pointKey in reviewStates[trazabilidadKey]!.keys) {
          final point = reviewStates[trazabilidadKey]![pointKey]!;
          if (!point.isApproved) {
            print('Rechazo encontrado en: $pointKey');
            hasRejections = true;
            break;
          }
        }
        if (hasRejections) break;
      }
      print('¿Tiene rechazos? $hasRejections');

      // Verificar puntos no aprobados sin comentario
      print('Verificando comentarios para puntos no aprobados...');
      String? missingReview;
      String? missingEPC;

      for (var entry in reviewStates.entries) {
        for (var pointEntry in entry.value.entries) {
          if (!pointEntry.value.isApproved) {
            print('Punto no aprobado: ${entry.key} - ${pointEntry.key}');
            if (pointEntry.value.comment == null ||
                pointEntry.value.comment!.isEmpty) {
              print(
                  'ERROR: Punto sin comentario: ${entry.key} - ${pointEntry.key}');
              missingReview = pointEntry.key;
              missingEPC = entry.key;
              break;
            } else {
              print('Comentario encontrado: ${pointEntry.value.comment}');
            }
          }
        }
        if (missingReview != null) break;
      }

      if (missingReview != null) {
        print('ERROR: Comentario requerido para $missingEPC - $missingReview');
        _showErrorDialog(
          context: context,
          title: 'Comentario Requerido',
          message: 'Falta indicar el motivo de no cumplimiento para:\n' +
              '"$missingReview"\n' +
              'de la trazabilidad $missingEPC',
        );
        setState(() => isLoading = false);
        return;
      }
      print('Verificación de comentarios completada con éxito');

      // Crear un certificado por defecto para cada producto
      final detalleEPCs = detailData!['detalleEPCs'] as List;
      Map<String, List<String>> productEPCs = {};

      for (var epc in detalleEPCs) {
        final claveProducto = epc['claveProducto'].toString();
        final trazabilidad = epc['trazabilidad'].toString();

        if (!productEPCs.containsKey(claveProducto)) {
          productEPCs[claveProducto] = [];
        }
        productEPCs[claveProducto]!.add(trazabilidad);
      }

      // Crear certificados por defecto para todos los productos
      for (var entry in productEPCs.entries) {
        if (!certificates.containsKey(entry.key)) {
          certificates[entry.key] = QualityCertificate(
            validationDate: DateTime.now(),
            relatedEPCs: entry.value,
          );
        }
      }

      // Obtener todos los valores necesarios de tu diálogo de confirmación
      print('Mostrando diálogo de confirmación...');
      final confirmationResult = await _showConfirmationDialog(
        context: context,
        hasRejections: hasRejections,
        certificates: certificates,
      );

      if (confirmationResult == null) {
        print('Cancelado por el usuario');
        setState(() => isLoading = false);
        return;
      }

      final String newStatus = confirmationResult['status'];
      final String validator = confirmationResult['validator'];
      final String timestamp = confirmationResult['timestamp'];
      print(
          'Datos de confirmación: status=$newStatus, validator=$validator, timestamp=$timestamp');

      // 1. Primero actualizar el estado de la revisión
      print('Actualizando estado de la revisión a: $newStatus');
      try {
        final statusResponse = await http.put(
          Uri.parse(
              'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/status'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newStatus),
        );

        print(
            'Respuesta de actualización de estado: ${statusResponse.statusCode}');
        print('Cuerpo de respuesta: ${statusResponse.body}');

        if (statusResponse.statusCode != 200 &&
            statusResponse.statusCode != 201) {
          throw Exception('Error al actualizar estado: ${statusResponse.body}');
        }
      } catch (e) {
        print('ERROR al actualizar estado: $e');
        throw Exception('Error al actualizar estado: $e');
      }

      // 2. Luego, para cada EPC, guardar su revisión de calidad
      print(
          'Procesando ${detalleEPCs.length} EPCs para revisión de calidad...');
      int epcCounter = 0;
      int successCount = 0;
      int failureCount = 0;
      List<String> failedEpcs = [];

      for (var epc in detalleEPCs) {
        epcCounter++;
        final trazabilidad = epc['trazabilidad'].toString();

        print('==== EPC #$epcCounter: $trazabilidad ====');

        try {
          // Preparar el FormData para este EPC
          print('Preparando request para $trazabilidad...');

          // URL correcta para el endpoint
          final endpoint =
              'http://172.16.10.31/api/QualityLogisticsReview/create';
          var request = http.MultipartRequest('POST', Uri.parse(endpoint));

          // Agregar trazabilidad en lugar de id_epc
          request.fields['trazabilidad'] = trazabilidad;
          request.fields['id_logistics_review'] = widget.reviewId.toString();
          print(
              'IDs configurados: trazabilidad=$trazabilidad, logistics_review=${widget.reviewId}');

          // Listar todas las claves en reviewStates para este EPC
          print('Claves disponibles para $trazabilidad:');
          reviewStates[trazabilidad]!.keys.forEach((key) {
            print('  - $key: ${reviewStates[trazabilidad]![key]!.isApproved}');
          });

          // Agregar puntos de revisión - Estado Físico
          try {
            print('Agregando puntos de Estado Físico...');
            request.fields['tarima_estado'] =
                reviewStates[trazabilidad]!['Tarima en buen estado']!
                    .isApproved
                    .toString();
            request.fields['empaque_sin_danos'] =
                reviewStates[trazabilidad]!['Empaque sin daños']!
                    .isApproved
                    .toString();
            request.fields['producto_limpio'] =
                reviewStates[trazabilidad]!['Producto limpio']!
                    .isApproved
                    .toString();
            request.fields['sin_deformaciones'] =
                reviewStates[trazabilidad]!['Sin deformaciones']!
                    .isApproved
                    .toString();
            request.fields['libre_de_plaga'] =
                reviewStates[trazabilidad]!['Libre de plaga']!
                    .isApproved
                    .toString();
            request.fields['flejado_correcto'] =
                reviewStates[trazabilidad]!['Flejado correcto']!
                    .isApproved
                    .toString();
          } catch (e) {
            print('ERROR al agregar puntos de Estado Físico: $e');
            throw Exception('Error con los puntos de Estado Físico: $e');
          }

          // Información y Etiquetado
          try {
            print('Agregando puntos de Información y Etiquetado...');
            request.fields['etiquetas_completas'] =
                reviewStates[trazabilidad]!['Etiquetas completas']!
                    .isApproved
                    .toString();
            request.fields['codigo_legible'] =
                reviewStates[trazabilidad]!['Códigos de barras legibles']!
                    .isApproved
                    .toString();
            request.fields['informacion_visible'] =
                reviewStates[trazabilidad]!['Información visible']!
                    .isApproved
                    .toString();
            request.fields['fechas_correctas'] =
                reviewStates[trazabilidad]!['Fechas correctas']!
                    .isApproved
                    .toString();
            request.fields['lote_visible'] =
                reviewStates[trazabilidad]!['Lote visible']!
                    .isApproved
                    .toString();
          } catch (e) {
            print('ERROR al agregar puntos de Información y Etiquetado: $e');
            throw Exception(
                'Error con los puntos de Información y Etiquetado: $e');
          }

          // Especificaciones
          try {
            print('Agregando puntos de Especificaciones...');
            request.fields['peso_correcto'] =
                reviewStates[trazabilidad]!['Peso correcto']!
                    .isApproved
                    .toString();
            request.fields['cantidad_correcta'] =
                reviewStates[trazabilidad]!['Cantidad de piezas correcta']!
                    .isApproved
                    .toString();
            request.fields['orden_correcta'] =
                reviewStates[trazabilidad]!['Orden de producción correcta']!
                    .isApproved
                    .toString();
            request.fields['unidad_correcta'] =
                reviewStates[trazabilidad]!['Unidad de medida correcta']!
                    .isApproved
                    .toString();
          } catch (e) {
            print('ERROR al agregar puntos de Especificaciones: $e');
            throw Exception('Error con los puntos de Especificaciones: $e');
          }

          // Recopilar comentarios de puntos no aprobados
          print('Recopilando comentarios...');
          final List<String> comments = [];
          for (var entry in reviewStates[trazabilidad]!.entries) {
            if (!entry.value.isApproved && entry.value.comment != null) {
              comments.add('${entry.key}: ${entry.value.comment}');
              print('  - Comentario para ${entry.key}: ${entry.value.comment}');
            }
          }

          // Asegurarse de que comentarios tenga un valor, incluso cuando esté vacío
          String commentText = comments.join('\n');
          if (commentText.isEmpty) {
            commentText =
                "Sin comentarios"; // Proporcionar un valor por defecto
            print(
                'No hay comentarios - usando valor por defecto: "Sin comentarios"');
          }

          // Obtener el certificado para este producto
          final claveProducto = epc['claveProducto'].toString();

          // IMPORTANTE: Asegurar que el validador nunca sea nulo o vacío
          String validatorValue = validator.trim();
          if (validatorValue.isEmpty) {
            validatorValue = "Sistema"; // Valor por defecto para validador
            print(
                'ADVERTENCIA: Validador estaba vacío, usando valor por defecto: "Sistema"');
          }

          // Formatear fecha de validación correctamente
          DateTime validationDate = DateTime.now();
          String fechaValidacion = "${validationDate.year}-"
              "${validationDate.month.toString().padLeft(2, '0')}-"
              "${validationDate.day.toString().padLeft(2, '0')}T"
              "${validationDate.hour.toString().padLeft(2, '0')}:"
              "${validationDate.minute.toString().padLeft(2, '0')}:"
              "${validationDate.second.toString().padLeft(2, '0')}";

          // Agregar comentarios y certificado (con valor fijo "POR SUBIR")
          print('Agregando datos de comentarios y certificado...');
          request.fields['comentarios'] = commentText;
          request.fields['validador'] = validatorValue;
          request.fields['certificado_calidad'] = "POR SUBIR";
          request.fields['fecha_validacion'] = fechaValidacion;
          request.fields['observaciones_certificado'] =
              "Certificado pendiente de subir";

          // Recopilar fotos para este EPC
          print('Procesando fotos...');
          final List<File> photos = [];
          for (var pointEntry in reviewStates[trazabilidad]!.entries) {
            if (!pointEntry.value.isApproved &&
                pointEntry.value.photo != null) {
              photos.add(pointEntry.value.photo!);
              print(
                  '  - Foto para ${pointEntry.key}: ${pointEntry.value.photo!.path}');
            }
          }

          print('Agregando ${photos.length} fotos al request...');
          // Añadir las fotos al request
          for (var i = 0; i < photos.length; i++) {
            try {
              final photo = photos[i];
              print('  - Procesando foto #${i + 1}: ${photo.path}');

              final stream = http.ByteStream(photo.openRead());
              final length = await photo.length();
              print('    Tamaño: $length bytes');

              final multipartFile = http.MultipartFile(
                'fotos',
                stream,
                length,
                filename:
                    '${trazabilidad}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
                contentType: MediaType('image', 'jpeg'),
              );

              request.files.add(multipartFile);
              print('    Foto añadida al request');
            } catch (e) {
              print('ERROR al procesar foto $i: $e');
            }
          }

          // Imprimir todos los campos para verificar
          print('==== CAMPOS DEL REQUEST ====');
          request.fields.forEach((key, value) {
            print('$key: $value');
          });
          print('==== FIN CAMPOS DEL REQUEST ====');

          // Enviar solicitud con reintento sin fotos si falla
          print('Enviando request para $trazabilidad a $endpoint...');
          try {
            final streamedResponse =
                await request.send().timeout(Duration(seconds: 30));
            print('Respuesta recibida. Status: ${streamedResponse.statusCode}');

            final response = await http.Response.fromStream(streamedResponse);
            print('Cuerpo de respuesta: ${response.body}');

            if (response.statusCode == 200 || response.statusCode == 201) {
              print('Revisión guardada correctamente para $trazabilidad');
              successCount++;
            } else {
              print(
                  'ERROR: Respuesta de error del servidor: ${response.statusCode}');
              print('Cuerpo de respuesta: ${response.body}');

              // Si hay error y tenemos fotos, intentar de nuevo sin fotos
              if (request.files.isNotEmpty) {
                print('Reintentando sin fotos...');
                var requestWithoutPhotos =
                    http.MultipartRequest('POST', Uri.parse(endpoint));
                requestWithoutPhotos.fields.addAll(request.fields);

                final retryResponse = await requestWithoutPhotos
                    .send()
                    .timeout(Duration(seconds: 30));
                final retryResponseBody =
                    await http.Response.fromStream(retryResponse);

                if (retryResponse.statusCode == 200 ||
                    retryResponse.statusCode == 201) {
                  print(
                      'Revisión guardada correctamente sin fotos para $trazabilidad');
                  successCount++;
                } else {
                  throw Exception(
                      'Error al guardar revisión (sin fotos): ${retryResponseBody.body}');
                }
              } else {
                throw Exception('Error al guardar revisión: ${response.body}');
              }
            }
          } catch (e) {
            print('ERROR al enviar request: $e');
            throw e; // Re-lanzar para manejar en el catch externo
          }
        } catch (e) {
          print('ERROR al procesar EPC $trazabilidad: $e');
          failureCount++;
          failedEpcs.add(trazabilidad);
          // Continuar con el siguiente EPC en lugar de detener todo el proceso
        }

        print('EPC $trazabilidad procesado.');
      }

      print(
          'Todos los EPCs procesados. $successCount exitosos, $failureCount fallidos.');
      if (failedEpcs.isNotEmpty) {
        print('EPCs fallidos: ${failedEpcs.join(", ")}');
      }

      // Si al menos algunos se procesaron correctamente, considerar la operación como exitosa
      if (successCount > 0) {
        setState(() => hasUnsavedChanges = false);

        if (mounted) {
          print('Navegando de vuelta...');
          Navigator.pop(context, true);

          String statusMessage = '';
          if (newStatus.contains('Rechazado')) {
            statusMessage = 'Revisión rechazada';
          } else if (newStatus.contains('Observaciones')) {
            statusMessage = 'Revisión aprobada con observaciones';
          } else {
            statusMessage = 'Revisión aprobada';
          }

          if (failureCount > 0) {
            statusMessage +=
                ' (${successCount}/${detalleEPCs.length} EPCs guardados)';
          } else {
            statusMessage += ' y guardada correctamente';
          }

          print('Mostrando mensaje de éxito: $statusMessage');
          _showSuccessMessage(statusMessage);
        }
      } else {
        throw Exception(
            'No se pudo guardar ninguna revisión. Verifica los errores e intenta nuevamente.');
      }

      print('==== PROCESO DE GUARDAR REVISIÓN COMPLETADO ====');
    } catch (e) {
      print('==== ERROR FATAL EN EL PROCESO DE GUARDAR ====');
      print('Excepción: $e');
      print('Stack trace: ${StackTrace.current}');
      _showErrorSnackBar('Error al guardar: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
      print('==== FIN DEL PROCESO ====');
    }
  }

  // Diálogo de confirmación mejorado
  Future<Map<String, dynamic>?> _showConfirmationDialog({
    required BuildContext context,
    required bool hasRejections,
    required Map<String, QualityCertificate> certificates,
  }) {
    // Obtener información necesaria del encabezado
    final encabezado = detailData?['encabezado'];
    final logisticaNumero = encabezado['no_Logistica'].toString();
    final cliente = encabezado['cliente'].toString();

    // Controlador para la persona que valida
    final validatorController = TextEditingController();

    // Estados posibles para la revisión
    final List<String> estadosRevisiones = [
      'Rechazado en Revisión de Calidad',
      'Aprobado con Observaciones en Calidad',
      'Aprobado en Revisión de Calidad'
    ];

    // Estado inicial basado en si hay rechazos
    String selectedStatus = hasRejections
        ? 'Rechazado en Revisión de Calidad'
        : 'Aprobado en Revisión de Calidad';

    // Fecha y hora actuales
    final now = DateTime.now();
    final formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(now);

    // Calcular resumen de productos y EPCs
    final Map<String, Map<String, dynamic>> productSummary = {};
    final detalleEPCs = detailData!['detalleEPCs'] as List;

    // Agrupar EPCs por producto y calcular estadísticas
    for (var epc in detalleEPCs) {
      final claveProducto = epc['claveProducto'].toString();
      final trazabilidad = epc['trazabilidad'].toString();

      if (!productSummary.containsKey(claveProducto)) {
        productSummary[claveProducto] = {
          'nombre': epc['nombreProducto'],
          'totalEPCs': 0,
          'pesoTotal': 0.0,
          'unidad': epc['claveUnidad'],
          'pasados': 0,
          'fallados': 0,
          'observaciones': 0,
        };
      }

      // Incrementar conteo de EPCs
      productSummary[claveProducto]!['totalEPCs'] =
          (productSummary[claveProducto]!['totalEPCs'] as int) + 1;

      // Sumar peso
      final peso = double.tryParse(epc['pesoNeto'].toString()) ?? 0.0;
      productSummary[claveProducto]!['pesoTotal'] =
          (productSummary[claveProducto]!['pesoTotal'] as double) + peso;

      // Calcular puntos pasados/fallados
      bool allPassed = true;
      bool hasFailed = false;
      bool hasObservations = false;

      if (reviewStates.containsKey(trazabilidad)) {
        final points = reviewStates[trazabilidad]!;
        for (var point in points.values) {
          if (!point.isApproved) {
            allPassed = false;
            hasFailed = true;
            if (point.comment != null && point.comment!.isNotEmpty) {
              hasObservations = true;
            }
          }
        }
      }

      if (allPassed) {
        productSummary[claveProducto]!['pasados'] =
            (productSummary[claveProducto]!['pasados'] as int) + 1;
      } else if (hasFailed) {
        productSummary[claveProducto]!['fallados'] =
            (productSummary[claveProducto]!['fallados'] as int) + 1;
      }

      if (hasObservations) {
        productSummary[claveProducto]!['observaciones'] =
            (productSummary[claveProducto]!['observaciones'] as int) + 1;
      }
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: 650, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado del Dialog
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fact_check,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirmación de Revisión de Calidad',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Resumen y aprobación final',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido principal (con scroll)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información de Logística
                          _buildInfoSection(
                            title: 'Información de Logística',
                            children: [
                              _buildInfoRow(
                                icon: Icons.inventory,
                                label: 'Número de Logística',
                                value: logisticaNumero,
                              ),
                              SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.business,
                                label: 'Cliente',
                                value: cliente,
                              ),
                              SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.calendar_today,
                                label: 'Fecha y Hora',
                                value: formattedDateTime,
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Selección de estado
                          _buildInfoSection(
                            title: 'Decisión de Calidad',
                            children: [
                              Text(
                                'Selecciona el estado final:',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Radio buttons para los estados
                              ...estadosRevisiones
                                  .map((estado) => RadioListTile<String>(
                                        title: Text(estado),
                                        value: estado,
                                        groupValue: selectedStatus,
                                        activeColor: estado
                                                .contains('Rechazado')
                                            ? errorColor
                                            : (estado.contains('Observaciones')
                                                ? warningColor
                                                : successColor),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedStatus = value!;
                                          });
                                        },
                                      ))
                                  .toList(),

                              SizedBox(height: 16),

                              // Campo para validador
                              TextField(
                                controller: validatorController,
                                decoration: InputDecoration(
                                  labelText: 'Persona que Valida *',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Resumen de productos
                          _buildInfoSection(
                            title: 'Resumen de Productos',
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: productSummary.length,
                                itemBuilder: (context, index) {
                                  final entry =
                                      productSummary.entries.elementAt(index);
                                  final producto = entry.key;
                                  final info = entry.value;

                                  return Card(
                                    margin: EdgeInsets.only(bottom: 16),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      info['nombre'] as String,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Clave: $producto',
                                                      style: TextStyle(
                                                        color: Colors.grey[700],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.info_outline,
                                                      size: 16,
                                                      color: Colors.grey[700],
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Certificado: POR SUBIR',
                                                      style: TextStyle(
                                                        color: Colors.grey[700],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: 12),

                                          // Información detallada
                                          Row(
                                            children: [
                                              _buildInfoChip(
                                                label: 'Total EPCs',
                                                value: info['totalEPCs']
                                                    .toString(),
                                                color: accentColor,
                                              ),
                                              SizedBox(width: 8),
                                              _buildInfoChip(
                                                label: 'Peso Total',
                                                value:
                                                    '${(info['pesoTotal'] as double).toStringAsFixed(2)} ${info['unidad']}',
                                                color: Colors.blue[700]!,
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: 8),

                                          // Resumen de revisiones
                                          Row(
                                            children: [
                                              _buildInfoChip(
                                                label: 'Pasados',
                                                value:
                                                    info['pasados'].toString(),
                                                color: successColor,
                                              ),
                                              SizedBox(width: 8),
                                              _buildInfoChip(
                                                label: 'Fallados',
                                                value:
                                                    info['fallados'].toString(),
                                                color: errorColor,
                                              ),
                                              SizedBox(width: 8),
                                              _buildInfoChip(
                                                label: 'Con Observaciones',
                                                value: info['observaciones']
                                                    .toString(),
                                                color: warningColor,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botones de acción
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancelar'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (validatorController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Por favor indica quién realiza la validación'),
                                  backgroundColor: errorColor,
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context, {
                              'status': selectedStatus,
                              'validator': validatorController.text,
                              'timestamp': now.toIso8601String(),
                              'summary': productSummary,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                selectedStatus.contains('Rechazado')
                                    ? errorColor
                                    : (selectedStatus.contains('Observaciones')
                                        ? warningColor
                                        : successColor),
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle),
                              SizedBox(width: 8),
                              Text('Confirmar Revisión'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Widget auxiliar para construir filas de información
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: primaryColor,
            size: 18,
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget auxiliar para construir chips de información
  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo de error mejorado
  Future<void> _showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? primaryActionText,
    VoidCallback? primaryAction,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: errorColor),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.pop(context),
          ),
          if (primaryActionText != null && primaryAction != null)
            ElevatedButton(
              child: Text(primaryActionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              onPressed: primaryAction,
            ),
        ],
      ),
    );
  }

  // Mensaje de éxito
  void _showSuccessMessage(String message) {
    if (!mounted) return;

    final Color bgColor = message.contains('rechazada')
        ? Colors.orange
        : (message.contains('observaciones')
            ? Colors.amber[700]!
            : successColor);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Restaurar estado anterior
  Future<void> _restorePreviousStatus() async {
    try {
      final response = await http.put(
        Uri.parse(
          'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/status',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': widget.previousStatus}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Error restaurando estado: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restaurando estado: $e');
    }
  }

  // Control de navegación hacia atrás
  Future<bool> _onWillPop() async {
    if (!hasUnsavedChanges) {
      await _restorePreviousStatus();
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cambios sin guardar'),
        content: Text('¿Deseas descartar los cambios y salir?'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text('Salir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (result == true) {
      await _restorePreviousStatus();
    }

    return result ?? false;
  }

  // Fetch Details
  Future<void> _fetchDetails() async {
    try {
      final response = await http
          .get(
            Uri.parse(
                'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/details'),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          detailData = data;
          _initializeReviewStates(data);
          isLoading = false;
        });
      } else {
        throw Exception('Error al cargar detalles: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  // Initialize Review States
  void _initializeReviewStates(Map<String, dynamic> data) {
    final detalleEPCs = data['detalleEPCs'] as List;
    for (var epc in detalleEPCs) {
      final trazabilidad = epc['trazabilidad'].toString();
      reviewStates[trazabilidad] = {};
      epcReviewedStatus[trazabilidad] = false; // Inicializar como no revisada

      for (var category in reviewCategories.entries) {
        for (var point in category.value) {
          reviewStates[trazabilidad]![point] = ReviewPoint();
        }
      }
    }
  }

  // Build Main Content
  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _fetchDetails,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'EPCs a Revisar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...(detailData!['detalleEPCs'] as List)
                .map((epc) => _buildEPCCard(epc)),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Build Error View
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: errorColor),
          SizedBox(height: 16),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: errorColor),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchDetails,
            child: Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // Main Build Method
  @override
  Widget build(BuildContext context) {
    // Obtener el padding del sistema para evitar la superposición con la barra de navegación
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          title: Text('Detalle de Revisión'),
          actions: [
            if (!isLoading)
              IconButton(
                icon: Icon(Icons.save),
                onPressed: _saveReview,
                tooltip: 'Guardar Revisión',
              ),
          ],
        ),
        body: SafeArea(
          // Con bottom: false para manejar manualmente el padding inferior
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? _buildErrorView()
                    : _buildMainContent(),
          ),
        ),
        floatingActionButton: _showBackToTop
            ? FloatingActionButton(
                onPressed: _scrollToTop,
                child: Icon(Icons.arrow_upward),
                mini: true,
              )
            : null,
      ),
    );
  }
}
