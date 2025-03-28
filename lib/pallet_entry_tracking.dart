// pallet_entry_tracking_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:zebra_scanner_app/models/pallet_entry_models.dart';

class PalletEntryTracking extends StatefulWidget {
  const PalletEntryTracking({Key? key}) : super(key: key);

  @override
  _PalletEntryTrackingState createState() => _PalletEntryTrackingState();
}

class _PalletEntryTrackingState extends State<PalletEntryTracking> {
  List<PalletEntry> palletEntries = [];
  List<PalletEntry> filteredEntries = [];
  bool isLoading = false;
  String searchQuery = '';
  PalletEntry? selectedPallet;

  // Status counters
  int totalCount = 0;
  int status2Count = 0; // Entró a almacén
  int status3Count = 0; // Se asignó ubicación
  int status4Count = 0; // Se dio de alta en SAP

  // Date range
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  // Controllers
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchPalletEntries();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Format date for API request
  String formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Format date for display
  String formatDateForDisplay(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Format date from string
  String formatDateFromString(String dateString) {
    if (dateString.isEmpty) return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  // Format time from string
  String formatTimeFromString(String dateString) {
    if (dateString.isEmpty) return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('HH:mm:ss').format(date);
    } catch (e) {
      return 'Hora inválida';
    }
  }

  // Fetch pallet entries from API
  Future<void> fetchPalletEntries() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'http://172.16.10.31/api/ProdExtraInfo/FiltrarTodoEntradaAlmacenPT?fechainicio=${formatDateForApi(startDate)}&fechafin=${formatDateForApi(endDate)}'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final entries = data.map((json) => PalletEntry.fromJson(json)).toList();

        // Update state
        setState(() {
          palletEntries = entries;
          filteredEntries = entries;
          isLoading = false;

          // Update counters
          updateStatusCounts(entries);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cargados ${entries.length} registros de tarimas'),
            backgroundColor: const Color(0xFF46707e),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Update status counts
  void updateStatusCounts(List<PalletEntry> entries) {
    setState(() {
      totalCount = entries.length;
      status2Count =
          entries.where((entry) => entry.prodEtiquetaRFID.status == 2).length;
      status3Count =
          entries.where((entry) => entry.prodEtiquetaRFID.status == 3).length;
      status4Count =
          entries.where((entry) => entry.prodEtiquetaRFID.status == 4).length;
    });
  }

  // Apply search filter
  void applySearch(String query) {
    if (palletEntries.isEmpty) return;

    setState(() {
      searchQuery = query.toLowerCase();

      if (searchQuery.isEmpty) {
        filteredEntries = palletEntries;
      } else {
        filteredEntries = palletEntries
            .where((entry) =>
                entry.trazabilidad.toLowerCase().contains(searchQuery) ||
                entry.prodEtiquetaRFID.claveProducto
                    .toLowerCase()
                    .contains(searchQuery) ||
                entry.prodEtiquetaRFID.nombreProducto
                    .toLowerCase()
                    .contains(searchQuery) ||
                entry.prodEtiquetaRFID.orden
                    .toLowerCase()
                    .contains(searchQuery))
            .toList();
      }

      updateStatusCounts(filteredEntries);
    });
  }

  // Filter by status
  void filterByStatus(int status) {
    setState(() {
      if (status == 0) {
        // Reset filter, show all entries
        filteredEntries = palletEntries;
      } else {
        filteredEntries = palletEntries
            .where((entry) => entry.prodEtiquetaRFID.status == status)
            .toList();
      }

      updateStatusCounts(filteredEntries);
    });
  }

  // Set today's date range
  void setTodayRange() {
    setState(() {
      startDate = DateTime.now();
      endDate = DateTime.now();
    });
    fetchPalletEntries();
  }

  // Set current week date range
  void setCurrentWeekRange() {
    final now = DateTime.now();
    final currentDay = now.weekday; // 1 is Monday

    final monday = now.subtract(Duration(days: currentDay - 1));
    final sunday = monday.add(const Duration(days: 6));

    setState(() {
      startDate = monday;
      endDate = sunday;
    });
    fetchPalletEntries();
  }

  // Set current month date range
  void setCurrentMonthRange() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    setState(() {
      startDate = firstDay;
      endDate = lastDay;
    });
    fetchPalletEntries();
  }

  // Select date (start or end)
  Future<void> selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? startDate : endDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF46707e),
              onPrimary: Colors.white,
              onSurface: Color(0xFF46707e),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          startDate = selectedDate;
        } else {
          endDate = selectedDate;
        }
      });
    }
  }

  // Get status text
  String getStatusText(int status) {
    switch (status) {
      case 2:
        return 'Ingresó a Almacén';
      case 3:
        return 'Asignado Ubicación';
      case 4:
        return 'Alta en SAP';
      default:
        return 'Desconocido';
    }
  }

  // Get status color
  Color getStatusColor(int status) {
    switch (status) {
      case 2:
        return const Color(0xFFFF9800); // Warning color
      case 3:
        return const Color(0xFF2196F3); // Info color
      case 4:
        return const Color(0xFF4CAF50); // Success color
      default:
        return Colors.grey;
    }
  }

  // Build status summary card
  Widget buildStatusSummaryCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(
            left: BorderSide(color: color, width: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF46707e).withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build status badge
  Widget buildStatusBadge(int status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusColor(status).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        getStatusText(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Build pallet card (original version, not used anymore)
  Widget buildPalletCard(PalletEntry pallet) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPallet = pallet;
        });
        _showPalletDetailsModal(context, pallet);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF46707e).withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF46707e), Color(0xFF3b5c6b)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Tarima #${pallet.numTarima}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  buildStatusBadge(pallet.prodEtiquetaRFID.status),
                ],
              ),
            ),

            // Card content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.inventory,
                        color: Color(0xFF46707e),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pallet.prodEtiquetaRFID.claveProducto,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF46707e),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pallet.prodEtiquetaRFID.nombreProducto,
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF46707e).withOpacity(0.8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Traceability
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping,
                        color: Color(0xFF46707e),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trazabilidad:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF46707e),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              pallet.trazabilidad,
                              style: const TextStyle(
                                color: Color(0xFF3b5c6b),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Entry date/time
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range,
                        color: Color(0xFF46707e),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Entrada:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF46707e),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${formatDateFromString(pallet.fechaEntrada)} ${formatTimeFromString(pallet.fechaEntrada)}',
                              style: const TextStyle(
                                color: Color(0xFF3b5c6b),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Info grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Peso Neto
                      buildInfoGridItem(Icons.scale, 'Peso Neto',
                          '${pallet.prodEtiquetaRFID.pesoNeto} kg'),

                      // Piezas
                      buildInfoGridItem(Icons.format_list_numbered, 'Piezas',
                          pallet.prodEtiquetaRFID.piezas.toString()),

                      // Orden
                      buildInfoGridItem(Icons.assignment, 'Orden',
                          pallet.prodEtiquetaRFID.orden),

                      // Área
                      buildInfoGridItem(
                          Icons.business, 'Área', pallet.prodEtiquetaRFID.area),
                    ],
                  ),
                ],
              ),
            ),

            // Card footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFd1e0e5).withOpacity(0.4),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF46707e).withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver detalles completos',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF46707e),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Color(0xFF46707e),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build info grid item - Modified for better adaptability
  Widget buildInfoGridItem(IconData icon, String label, String value) {
    // Calculate width based on screen size
    final width = (MediaQuery.of(context).size.width - 60) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFd1e0e5).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF46707e).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF46707e).withOpacity(0.8),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF46707e).withOpacity(0.8),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF46707e),
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

  // Build detail section
  Widget buildDetailSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF46707e),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF46707e),
                        const Color(0xFF46707e).withOpacity(0.0)
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items,
        ),
      ],
    );
  }

  // Build detail item with improved adaptability
  Widget buildDetailItem(String label, String value,
      {bool isFullWidth = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: isFullWidth ? double.infinity : (screenWidth - 65) / 2,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFd1e0e5).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF46707e).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF46707e).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF46707e),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // Show pallet details modal
  void _showPalletDetailsModal(BuildContext context, PalletEntry pallet) {
    // Use LayoutBuilder to adapt to available screen space
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Column(
            children: [
              // Modal header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF46707e), Color(0xFF3b5c6b)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle de Tarima #${pallet.numTarima}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          buildStatusBadge(pallet.prodEtiquetaRFID.status),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

              // Modal body - Make it scrollable to handle overflow
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // General Information
                    buildDetailSection(
                      'Información General',
                      [
                        buildDetailItem('ID en Sistema', pallet.id.toString()),
                        buildDetailItem(
                            'RFID ID', pallet.prodEtiquetaRFIDId.toString()),
                        buildDetailItem('Trazabilidad', pallet.trazabilidad),
                        buildDetailItem('RFID', pallet.prodEtiquetaRFID.rfid),
                        buildDetailItem('Antena', pallet.antena),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Product Information
                    buildDetailSection(
                      'Información del Producto',
                      [
                        buildDetailItem('Nombre del Producto',
                            pallet.prodEtiquetaRFID.nombreProducto,
                            isFullWidth: true),
                        buildDetailItem('Clave del Producto',
                            pallet.prodEtiquetaRFID.claveProducto),
                        buildDetailItem('Área', pallet.prodEtiquetaRFID.area),
                        buildDetailItem('Orden', pallet.prodEtiquetaRFID.orden),
                        buildDetailItem('Unidad de Medida',
                            '${pallet.prodEtiquetaRFID.claveUnidad} (${pallet.prodEtiquetaRFID.uom})'),
                        buildDetailItem('Costo', pallet.prodEtiquetaRFID.costo),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Weight and Quantity Information
                    buildDetailSection(
                      'Información de Peso y Cantidad',
                      [
                        buildDetailItem('Peso Tarima',
                            '${pallet.prodEtiquetaRFID.pesoTarima} kg'),
                        buildDetailItem('Peso Bruto',
                            '${pallet.prodEtiquetaRFID.pesoBruto} kg'),
                        buildDetailItem('Peso Neto',
                            '${pallet.prodEtiquetaRFID.pesoNeto} kg'),
                        buildDetailItem('Piezas',
                            pallet.prodEtiquetaRFID.piezas.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Nuevo diseño de tarjeta de tarima basado en LogisticaListScreen
  Widget buildPalletCardNew(PalletEntry pallet) {
    // Color base del diseño
    Color baseColor = const Color(0xFF85B6C4);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            offset: const Offset(0, 2),
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
            _showPalletDetailsModal(context, pallet);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: baseColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: baseColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarima #${pallet.numTarima}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            'ID: ${pallet.id}',
                            style: TextStyle(
                              fontSize: 13,
                              color: baseColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: getStatusColor(pallet.prodEtiquetaRFID.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        getStatusText(pallet.prodEtiquetaRFID.status),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Información Principal
                Container(
                  padding: const EdgeInsets.all(12),
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Primera columna - Producto
                      Expanded(
                        child: _buildColumnInfoItem(
                          Icons.inventory,
                          'Producto',
                          pallet.prodEtiquetaRFID.claveProducto,
                          Colors.indigo,
                        ),
                      ),
                      // Separador vertical
                      VerticalDivider(
                        color: Colors.grey[200],
                        width: 20,
                      ),
                      // Segunda columna - Área
                      Expanded(
                        child: _buildColumnInfoItem(
                          Icons.business,
                          'Área',
                          pallet.prodEtiquetaRFID.area,
                          Colors.teal,
                        ),
                      ),
                      // Separador vertical
                      VerticalDivider(
                        color: Colors.grey[200],
                        width: 20,
                      ),
                      // Tercera columna - Fecha
                      Expanded(
                        child: _buildColumnInfoItem(
                          Icons.calendar_today_outlined,
                          'Entrada',
                          formatDateFromString(pallet.fechaEntrada),
                          Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Detalles Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Datos de Trazabilidad',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Información de Trazabilidad
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trazabilidad
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.qr_code,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trazabilidad',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  pallet.trazabilidad,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Información de peso y piezas en contenedores
                      Row(
                        children: [
                          // Peso Neto
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.scale,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Peso Neto',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '${pallet.prodEtiquetaRFID.pesoNeto} kg',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Piezas
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.format_list_numbered,
                                    color: Colors.purple,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Piezas',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          pallet.prodEtiquetaRFID.piezas
                                              .toString(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Orden
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.assignment,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Orden',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          pallet.prodEtiquetaRFID.orden,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Footer con botón de "Ver detalles"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: baseColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ver detalles completos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: baseColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: baseColor,
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

  // Método para construir elementos de información en columnas
  Widget _buildColumnInfoItem(
      IconData icon, String label, String value, Color baseColor) {
    return Container(
      padding: const EdgeInsets.all(8),
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
                padding: const EdgeInsets.all(4),
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
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

  // Build filter chip
  Widget _buildFilterChip({
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Date range selector and search bar
          Container(
            color: const Color(0xFF46707e).withOpacity(0.05),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Date range row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          selectDate(context, true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF46707e).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFF46707e),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatDateForDisplay(startDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF46707e),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'a',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF46707e),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          selectDate(context, false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF46707e).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFF46707e),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatDateForDisplay(endDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF46707e),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Quick date selection chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: setTodayRange,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: const Color(0xFF46707e).withOpacity(0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Hoy',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF46707e),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: setCurrentWeekRange,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: const Color(0xFF46707e).withOpacity(0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Esta Semana',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF46707e),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: setCurrentMonthRange,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: const Color(0xFF46707e).withOpacity(0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Este Mes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF46707e),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF46707e).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: applySearch,
                    decoration: InputDecoration(
                      hintText: 'Buscar por trazabilidad, producto, orden...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF46707e).withOpacity(0.5),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: const Color(0xFF46707e).withOpacity(0.7),
                        size: 20,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchController.clear();
                                applySearch('');
                              },
                              color: const Color(0xFF46707e).withOpacity(0.7),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Filter chip buttons for status
                Row(
                  children: [
                    _buildFilterChip(
                      label: 'Todos',
                      count: totalCount,
                      color: const Color(0xFF46707e),
                      onTap: () {
                        filterByStatus(0);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Ingresados',
                      count: status2Count,
                      color: const Color(0xFFFF9800),
                      onTap: () {
                        filterByStatus(2);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Ubicados',
                      count: status3Count,
                      color: const Color(0xFF2196F3),
                      onTap: () {
                        filterByStatus(3);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'En SAP',
                      count: status4Count,
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        filterByStatus(4);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status summary cards
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: buildStatusSummaryCard(
                    icon: Icons.all_inbox,
                    label: 'Total',
                    count: totalCount,
                    color: const Color(0xFF46707e),
                    onTap: () {
                      filterByStatus(0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildStatusSummaryCard(
                    icon: Icons.login,
                    label: 'Ingresados',
                    count: status2Count,
                    color: const Color(0xFFFF9800),
                    onTap: () {
                      filterByStatus(2);
                    },
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: buildStatusSummaryCard(
                    icon: Icons.place,
                    label: 'Ubicados',
                    count: status3Count,
                    color: const Color(0xFF2196F3),
                    onTap: () {
                      filterByStatus(3);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildStatusSummaryCard(
                    icon: Icons.cloud_done,
                    label: 'En SAP',
                    count: status4Count,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      filterByStatus(4);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content - Pallet list
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: const Color(0xFF46707e),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cargando datos...',
                          style: TextStyle(
                            color: const Color(0xFF46707e),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2,
                              color: const Color(0xFF46707e).withOpacity(0.3),
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron tarimas',
                              style: TextStyle(
                                color: const Color(0xFF46707e).withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                searchController.clear();
                                applySearch('');
                                filterByStatus(0); // Mostrar todos
                                fetchPalletEntries();
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Actualizar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF46707e),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchPalletEntries,
                        color: const Color(0xFF46707e),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            return buildPalletCardNew(filteredEntries[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: fetchPalletEntries,
        backgroundColor: const Color(0xFF46707e),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
