import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:intl/intl.dart';

// Modelo para Certificado de Calidad
class QualityCertificate {
  String certificateNumber;
  String validator;
  DateTime validationDate;
  String observations;
  List<String> relatedEPCs;

  QualityCertificate({
    required this.certificateNumber,
    required this.validator,
    required this.validationDate,
    this.observations = '',
    required this.relatedEPCs,
  });

  Map<String, dynamic> toJson() => {
        'certificateNumber': certificateNumber,
        'validator': validator,
        'validationDate': validationDate.toIso8601String(),
        'observations': observations,
        'relatedEPCs': relatedEPCs,
      };
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
    extends State<LogisticsReviewDetailScreen> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detailData;
  Map<String, Map<String, ReviewPoint>> reviewStates = {};
  Map<String, QualityCertificate> certificates = {};
  final ImagePicker _imagePicker = ImagePicker();
  bool hasUnsavedChanges = false;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  // Colores personalizados mejorados
  final Color primaryColor = const Color(0xFF2C3E50);
  final Color accentColor = const Color(0xFF3498DB);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color cardColor = Colors.white;
  final Color successColor = const Color(0xFF2ECC71);
  final Color warningColor = const Color(0xFFF1C40F);
  final Color errorColor = const Color(0xFFE74C3C);

  // Controladores para el certificado
  final TextEditingController certificateController = TextEditingController();
  final TextEditingController validatorController = TextEditingController();
  final TextEditingController observationsController = TextEditingController();

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
    certificateController.dispose();
    validatorController.dispose();
    observationsController.dispose();
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
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
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
                ],
              ),
            ),
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
          _buildProductInfoRow(
              'Peso Neto', '${epc['pesoNeto']} ${epc['claveUnidad']}'),
          Divider(height: 20),
          _buildProductInfoRow('Piezas', epc['piezas'].toString()),
          Divider(height: 20),
          _buildProductInfoRow('Orden', epc['orden']),
          SizedBox(height: 16),
          _buildCertificateStatus(
            epc['claveProducto'].toString(),
            [epc as Map<String, dynamic>],
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

  // Método para mostrar el estado del certificado
  Widget _buildCertificateStatus(
      String claveProducto, List<Map<String, dynamic>> epcs) {
    final hasCertificate = certificates.containsKey(claveProducto);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            hasCertificate ? successColor.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasCertificate
              ? successColor.withOpacity(0.3)
              : Colors.grey[300]!,
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
              hasCertificate ? Icons.verified_user : Icons.pending,
              color: hasCertificate ? successColor : Colors.grey[400],
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCertificate
                      ? 'Certificado No. ${certificates[claveProducto]!.certificateNumber}'
                      : 'Certificado Pendiente',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                if (hasCertificate)
                  Text(
                    'Validado por: ${certificates[claveProducto]!.validator}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            icon: Icon(
              hasCertificate ? Icons.edit : Icons.add,
              size: 18,
            ),
            label: Text(hasCertificate ? 'Editar' : 'Agregar'),
            onPressed: () => _showCertificateModal(claveProducto, epcs),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
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

  // Modal de Certificado de Calidad mejorado
  void _showCertificateModal(
      String productKey, List<Map<String, dynamic>> epcs) async {
    final certificate = certificates[productKey] ??
        QualityCertificate(
          certificateNumber: '',
          validator: '',
          validationDate: DateTime.now(),
          relatedEPCs: epcs.map((e) => e['trazabilidad'].toString()).toList(),
        );

    certificateController.text = certificate.certificateNumber;
    validatorController.text = certificate.validator;
    observationsController.text = certificate.observations;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado del Modal
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user,
                            color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Certificado de Calidad',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Producto: $productKey',
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
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Número de Certificado
                        _buildCertificateField(
                          controller: certificateController,
                          label: 'Número de Certificado',
                          icon: Icons.numbers,
                          required: true,
                        ),
                        SizedBox(height: 16),

                        // Validador
                        _buildCertificateField(
                          controller: validatorController,
                          label: 'Validador',
                          icon: Icons.person,
                          required: true,
                        ),
                        SizedBox(height: 16),

                        // Fecha de Validación
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha de Validación',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      color: primaryColor, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm')
                                        .format(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Observaciones
                        TextField(
                          controller: observationsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Observaciones',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.note, color: primaryColor),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Lista de EPCs
                        Text(
                          'EPCs Asociados',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          constraints: BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: epcs.length,
                            itemBuilder: (context, index) {
                              final epc = epcs[index];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: index < epcs.length - 1
                                          ? Colors.grey[200]!
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.tag,
                                      size: 16,
                                      color: accentColor,
                                    ),
                                  ),
                                  title: Text(
                                    epc['trazabilidad'].toString(),
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    'Peso: ${epc['pesoNeto']} ${epc['claveUnidad']}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancelar'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text('Guardar Certificado'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            if (certificateController.text.isEmpty ||
                                validatorController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Por favor complete los campos requeridos',
                                  ),
                                  backgroundColor: errorColor,
                                ),
                              );
                              return;
                            }

                            certificates[productKey] = QualityCertificate(
                              certificateNumber: certificateController.text,
                              validator: validatorController.text,
                              validationDate: DateTime.now(),
                              observations: observationsController.text,
                              relatedEPCs: epcs
                                  .map((e) => e['trazabilidad'].toString())
                                  .toList(),
                            );

                            setState(() {
                              hasUnsavedChanges = true;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget auxiliar para campos del certificado
  Widget _buildCertificateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (required)
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        if (!required)
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(icon, color: primaryColor),
            ),
            hintText: 'Ingrese $label',
          ),
        ),
      ],
    );
  }

  // Función de guardado modificada
  Future<void> _saveReview() async {
    // Verificar certificados faltantes
    final Map<String, List<Map<String, dynamic>>> productGroups = {};
    final detalleEPCs = detailData!['detalleEPCs'] as List;

    // Agrupar EPCs por producto
    for (var epc in detalleEPCs) {
      final claveProducto = epc['claveProducto'].toString();
      productGroups[claveProducto] = productGroups[claveProducto] ?? [];
      productGroups[claveProducto]!.add(epc);
    }

    // Verificar certificados faltantes
    final List<String> missingCertificates = [];
    for (var claveProducto in productGroups.keys) {
      if (!certificates.containsKey(claveProducto)) {
        missingCertificates.add(claveProducto);
      }
    }

    if (missingCertificates.isNotEmpty) {
      _showErrorDialog(
        context: context,
        title: 'Certificados Pendientes',
        message:
            'Faltan certificados de calidad para los siguientes productos:\n\n' +
                missingCertificates.map((clave) => '• $clave').join('\n'),
        primaryActionText: 'Agregar Certificado',
        primaryAction: () {
          Navigator.pop(context);
          _showCertificateModal(
            missingCertificates.first,
            productGroups[missingCertificates.first]!,
          );
        },
      );
      return;
    }

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
      _showErrorDialog(
        context: context,
        title: 'Comentario Requerido',
        message: 'Falta indicar el motivo de no cumplimiento para:\n' +
            '"$missingReview"\n' +
            'de la trazabilidad $missingEPC',
      );
      return;
    }

    // Determinar estado final
    final String newStatus = hasRejections
        ? "Rechazado en Revisión de Calidad"
        : "Aprobado por Calidad";

    // Mostrar diálogo de confirmación
    final bool? confirm = await _showConfirmationDialog(
      context: context,
      hasRejections: hasRejections,
      certificates: certificates,
    );

    if (confirm != true) return;

    try {
      setState(() => isLoading = true);

      // Preparar datos
      final reviewData = {
        'status': newStatus,
        'certificates':
            certificates.map((key, value) => MapEntry(key, value.toJson())),
        'reviewStates': reviewStates.map((key, value) => MapEntry(
              key,
              value.map((k, v) => MapEntry(k, {
                    'isApproved': v.isApproved,
                    'comment': v.comment,
                    'hasPhoto': v.photo != null,
                  })),
            )),
      };

      // Enviar revisión
      final response = await http.put(
        Uri.parse(
          'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/status',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(reviewData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Enviar fotos
        await _uploadPhotos();

        setState(() => hasUnsavedChanges = false);
        if (mounted) {
          Navigator.pop(context, true);
          _showSuccessMessage(
            hasRejections
                ? 'Revisión rechazada y guardada correctamente'
                : 'Revisión aprobada y guardada correctamente',
          );
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

  // Función para subir fotos
  Future<void> _uploadPhotos() async {
    for (var trazabilidad in reviewStates.keys) {
      for (var point in reviewStates[trazabilidad]!.keys) {
        final reviewPoint = reviewStates[trazabilidad]![point]!;
        if (reviewPoint.photo != null) {
          final photoData = await reviewPoint.photo!.readAsBytes();
          final photoResponse = await http.post(
            Uri.parse(
              'http://172.16.10.31/api/logistics_to_review/${widget.reviewId}/photos',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'trazabilidad': trazabilidad,
              'point': point,
              'photo': base64Encode(photoData),
            }),
          );
          if (photoResponse.statusCode != 200 &&
              photoResponse.statusCode != 201) {
            throw Exception(
              'Error al subir foto para $trazabilidad - $point',
            );
          }
        }
      }
    }
  }

  // Diálogo de confirmación mejorado
  Future<bool?> _showConfirmationDialog({
    required BuildContext context,
    required bool hasRejections,
    required Map<String, QualityCertificate> certificates,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Icon(
                    hasRejections ? Icons.warning : Icons.check_circle,
                    color: hasRejections ? errorColor : successColor,
                    size: 28,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      hasRejections
                          ? 'Confirmar Rechazo'
                          : 'Confirmar Aprobación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Mensaje principal
              Text(
                hasRejections
                    ? '¿Deseas finalizar la revisión? El material será marcado como rechazado.'
                    : '¿Deseas finalizar y aprobar la revisión de calidad?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24),

              // Resumen de Certificados
              Text(
                'Certificados de Calidad:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: certificates.length,
                  itemBuilder: (context, index) {
                    final entry = certificates.entries.elementAt(index);
                    return Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index < certificates.length - 1
                                ? Colors.grey[200]!
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.verified,
                              color: successColor,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Producto ${entry.key}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  'Cert. ${entry.value.certificateNumber}',
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
                    );
                  },
                ),
              ),
              SizedBox(height: 24),

              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: Text('Cancelar'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    child: Text('Confirmar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasRejections ? errorColor : successColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successColor,
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
        body: json.encode("Material Separado"),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Error restoring status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restoring status: $e');
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

      for (var category in reviewCategories.entries) {
        for (var point in category.value) {
          reviewStates[trazabilidad]![point] = ReviewPoint();
        }
      }
    }
  }

  // Cleanup Temp Files
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

  // Take Photo
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
        _showCommentDialog(trazabilidad, point);
      }
    } catch (e) {
      _showErrorSnackBar('Error al tomar la foto: $e');
    }
  }

  // Show Full Screen Image
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

  // Show Comment Dialog
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
        content: SingleChildScrollView(
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
              if (reviewPoint.photo != null) ...[
                SizedBox(height: 16),
                Text('Foto adjunta:'),
                SizedBox(height: 8),
                InkWell(
                  onTap: () => _showFullScreenImage(reviewPoint.photo!),
                  child: Hero(
                    tag: reviewPoint.photo!.path,
                    child: Image.file(
                      reviewPoint.photo!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
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

  // Build Review Category
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

  // Build Checkbox Item
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
              Text(
                'Motivo:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              Text(reviewPoint.comment!),
              if (reviewPoint.photo != null) ...[
                SizedBox(height: 8),
                InkWell(
                  onTap: () => _showFullScreenImage(reviewPoint.photo!),
                  child: Hero(
                    tag: reviewPoint.photo!.path,
                    child: Image.file(
                      reviewPoint.photo!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Main Build Method
  @override
  Widget build(BuildContext context) {
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
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? _buildErrorView()
                  : _buildMainContent(),
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
}
