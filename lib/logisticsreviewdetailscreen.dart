import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';

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
    extends State<LogisticsReviewDetailScreen> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detailData;
  Map<String, Map<String, ReviewPoint>> reviewStates = {};
  final ImagePicker _imagePicker = ImagePicker();
  bool hasUnsavedChanges = false;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  // Colores personalizados
  final Color primaryColor = const Color(0xFF1976D2);
  final Color secondaryColor = const Color(0xFF64B5F6);
  final Color backgroundColor = const Color(0xFFF5F5F5);
  final Color cardColor = Colors.white;
  final Color successColor = const Color(0xFF4CAF50);
  final Color warningColor = const Color(0xFFFFA726);
  final Color errorColor = const Color(0xFFE53935);

  // Categorías de revisión
  final Map<String, List<String>> reviewCategories = {
    'Estado Físico': [
      'Tarima en buen estado',
      'Empaque sin daños',
      'Producto limpio',
      'Sin deformaciones',
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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= 400) {
      if (!_showBackToTop) setState(() => _showBackToTop = true);
    } else {
      if (_showBackToTop) setState(() => _showBackToTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutQuad,
    );
  }

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

  void _initializeReviewStates(Map<String, dynamic> data) {
    final detalleEPCs = data['detalleEPCs'] as List;
    for (var epc in detalleEPCs) {
      final trazabilidad = epc['trazabilidad'].toString();
      reviewStates[trazabilidad] = {};

      for (var category in reviewCategories.entries) {
        for (var point in category.value) {
          reviewStates[trazabilidad]![point] = ReviewPoint();
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
          textColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _takePhoto(String trazabilidad, String point) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null && mounted) {
        setState(() {
          reviewStates[trazabilidad]![point]!.photo = File(photo.path);
          hasUnsavedChanges = true;
        });
        // Volver a mostrar el diálogo de comentario con la foto actualizada
        _showCommentDialog(trazabilidad, point);
      }
    } catch (e) {
      _showErrorSnackBar('Error al tomar la foto: $e');
    }
  }

  void _showFullScreenImage(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: imageFile.path,
                child: Image.file(imageFile),
              ),
            ),
            Positioned(
              top: -12,
              right: -12,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentDialog(String trazabilidad, String point) {
    final reviewPoint = reviewStates[trazabilidad]![point]!;
    final commentController = TextEditingController(text: reviewPoint.comment);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: warningColor),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Indicar motivo de no cumplimiento',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
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
                  fillColor: Colors.grey.shade50,
                ),
                autofocus: true,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.camera_alt),
                    label: Text('Tomar Foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Guardar el comentario actual antes de tomar la foto
                      reviewPoint.comment = commentController.text;
                      Navigator.pop(context);
                      _takePhoto(trazabilidad, point);
                    },
                  ),
                  if (reviewPoint.photo != null)
                    TextButton.icon(
                      icon: Icon(Icons.delete, color: Colors.red),
                      label: Text('Eliminar Foto',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        setState(() {
                          reviewPoint.photo = null;
                          hasUnsavedChanges = true;
                        });
                      },
                    ),
                ],
              ),
              if (reviewPoint.photo != null) ...[
                SizedBox(height: 16),
                Text(
                  'Foto adjunta:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: () => _showFullScreenImage(reviewPoint.photo!),
                  child: Hero(
                    tag: 'photo_${point}_${trazabilidad}',
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(reviewPoint.photo!),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () {
              // Si se cancela, revertir a aprobado
              setState(() {
                reviewPoint.isApproved = true;
                reviewPoint.comment = null;
                reviewPoint.photo = null;
                hasUnsavedChanges = true;
              });
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: Text('Guardar'),
            onPressed: () {
              if (commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Por favor, indica el motivo de no cumplimiento'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSelectOption({
    required String label,
    required bool value,
    required ReviewPoint reviewPoint,
    required String trazabilidad,
    required String point,
  }) {
    final isSelected = reviewPoint.isApproved == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            reviewPoint.isApproved = value;
            hasUnsavedChanges = true;

            if (!value) {
              // Si selecciona "No"
              _showCommentDialog(trazabilidad, point);
            } else {
              // Si selecciona "Sí"
              reviewPoint.comment = null;
              reviewPoint.photo = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (value
                    ? successColor.withOpacity(0.1)
                    : errorColor.withOpacity(0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? (value ? successColor : errorColor)
                  : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxItem(String point, String trazabilidad) {
    final reviewPoint = reviewStates[trazabilidad]![point]!;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: reviewPoint.isApproved ? successColor : errorColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSelectOption(
                        label: 'Sí',
                        value: true,
                        reviewPoint: reviewPoint,
                        trazabilidad: trazabilidad,
                        point: point,
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.grey[300],
                      ),
                      _buildSelectOption(
                        label: 'No',
                        value: false,
                        reviewPoint: reviewPoint,
                        trazabilidad: trazabilidad,
                        point: point,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!reviewPoint.isApproved &&
                (reviewPoint.comment != null || reviewPoint.photo != null))
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reviewPoint.comment != null &&
                        reviewPoint.comment!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.comment,
                              size: 16, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            'Motivo:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        reviewPoint.comment!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                    if (reviewPoint.photo != null) ...[
                      if (reviewPoint.comment != null &&
                          reviewPoint.comment!.isNotEmpty)
                        SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.photo, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            'Evidencia:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showFullScreenImage(reviewPoint.photo!),
                        child: Hero(
                          tag: 'photo_${point}_${trazabilidad}',
                          child: Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(reviewPoint.photo!),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final encabezado = detailData?['encabezado'];
    if (encabezado == null) return SizedBox();

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.9),
            secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '#${encabezado['no_Logistica']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        encabezado['estatus'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                _buildHeaderInfo(encabezado),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // Agregar estos métodos a la clase _LogisticsReviewDetailScreenState

  Widget _buildEPCCard(Map<String, dynamic> epc) {
    final trazabilidad = epc['trazabilidad'].toString();
    bool isAllReviewed = reviewStates[trazabilidad]
            ?.values
            .every((point) => point.isApproved || point.comment != null) ??
        false;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isAllReviewed
              ? successColor.withOpacity(0.3)
              : warningColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAllReviewed
                  ? successColor.withOpacity(0.1)
                  : warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAllReviewed ? Icons.check_circle : Icons.pending,
              color: isAllReviewed ? successColor : warningColor,
              size: 24,
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
                  color: primaryColor,
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
            _buildEPCDetails(epc, trazabilidad),
          ],
        ),
      ),
    );
  }

  Widget _buildEPCDetails(Map<String, dynamic> epc, String trazabilidad) {
    return Container(
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
              color: primaryColor,
            ),
          ),
          SizedBox(height: 16),
          ...reviewCategories.entries.map((category) =>
              _buildReviewCategory(category.key, category.value, trazabilidad)),
        ],
      ),
    );
  }
  // Agregar estos métodos a la clase _LogisticsReviewDetailScreenState

  Future<void> _restorePreviousStatus() async {
    try {
      final response = await http.put(
        Uri.parse(
            'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode("Material Separado"), // Changed to fixed status
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Error restoring status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restoring status: $e');
    }
  }

  Widget _buildReviewCategory(
      String categoryName, List<String> points, String trazabilidad) {
    bool isCategoryComplete = points.every((point) =>
        reviewStates[trazabilidad]![point]!.isApproved ||
        (reviewStates[trazabilidad]![point]!.comment != null &&
            !reviewStates[trazabilidad]![point]!.isApproved));

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCategoryComplete ? Icons.check_circle : Icons.pending,
                  color: isCategoryComplete ? successColor : warningColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCategoryComplete ? successColor : warningColor)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isCategoryComplete ? successColor : warningColor)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isCategoryComplete ? 'Completado' : 'Pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCategoryComplete ? successColor : warningColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          AnimatedSize(
            duration: Duration(milliseconds: 300),
            child: Column(
              children: points
                  .map((point) => _buildCheckboxItem(point, trazabilidad))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfoCard(Map<String, dynamic> epc) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildProductInfoRow('Clave de Producto', epc['claveProducto']),
          Divider(height: 20),
          _buildProductInfoRow(
              'Peso Neto', '${epc['pesoNeto']} ${epc['claveUnidad']}'),
          Divider(height: 20),
          _buildProductInfoRow('Piezas', epc['piezas'].toString()),
          Divider(height: 20),
          _buildProductInfoRow('Orden', epc['orden']),
        ],
      ),
    );
  }

  Widget _buildProductInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }

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

  Future<void> _saveReview() async {
    // Verificar puntos no aprobados sin comentario
    String? missingReview;
    String? missingEPC;
    bool hasRejections = false;

    for (var entry in reviewStates.entries) {
      for (var pointEntry in entry.value.entries) {
        if (!pointEntry.value.isApproved) {
          hasRejections = true;
          if (pointEntry.value.comment == null) {
            missingReview = pointEntry.key;
            missingEPC = entry.key;
            break;
          }
        }
      }
      if (missingReview != null) break;
    }

    if (missingReview != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Falta indicar el motivo de no cumplimiento para "$missingReview" de la trazabilidad $missingEPC'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    final newStatus = hasRejections
        ? "Rechazado en Revisión de Calidad"
        : "Revisión Completada";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(hasRejections ? Icons.warning : Icons.save,
                color: hasRejections ? warningColor : primaryColor),
            SizedBox(width: 8),
            Text(hasRejections ? 'Confirmar Rechazo' : 'Confirmar Revisión'),
          ],
        ),
        content: Text(hasRejections
            ? '¿Deseas finalizar la revisión? El material será marcado como rechazado.'
            : '¿Deseas finalizar y guardar la revisión de calidad?'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasRejections ? errorColor : primaryColor,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isLoading = true);

      final response = await http.put(
        Uri.parse(
            'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newStatus),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => hasUnsavedChanges = false);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Error al guardar la revisión: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: errorColor,
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: errorColor,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchDetails,
            icon: Icon(Icons.refresh),
            label: Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(Map<String, dynamic> encabezado) {
    final infoItems = [
      {
        'icon': Icons.business,
        'label': 'Cliente',
        'value': encabezado['cliente'],
      },
      {
        'icon': Icons.person,
        'label': 'Operador',
        'value': encabezado['operador_Separador'],
      },
      {
        'icon': Icons.tag,
        'label': 'EPCs Total',
        'value': encabezado['noEPCs'].toString(),
      },
      {
        'icon': Icons.update,
        'label': 'Última Actualización',
        'value': _formatDateTime(encabezado['lastUpdate']),
      },
    ];

    return Column(
      children: infoItems
          .map((item) => Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            item['value'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  String _formatDateTime(String dateTime) {
    final date = DateTime.parse(dateTime).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _fetchDetails,
      color: primaryColor,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: primaryColor,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'EPCs a Revisar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          title: Text(
            'Detalle de Revisión',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (!isLoading)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(Icons.save),
                  onPressed: _saveReview,
                  tooltip: 'Guardar Revisión',
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Cargando...',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : errorMessage != null
                  ? _buildErrorView()
                  : _buildMainContent(),
        ),
        floatingActionButton: _showBackToTop
            ? FloatingActionButton(
                onPressed: _scrollToTop,
                child: Icon(Icons.arrow_upward),
                backgroundColor: primaryColor,
                mini: true,
              )
            : null,
      ),
    );
  }
}
