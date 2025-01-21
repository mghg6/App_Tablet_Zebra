import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QualityReviewModal extends StatefulWidget {
  final List<String> scannedEpcs;
  final int noLogistica; // Agregamos el número de logística

  const QualityReviewModal(
      {Key? key,
      required this.scannedEpcs,
      required this.noLogistica // Requerimos el número de logística
      })
      : super(key: key);

  @override
  _QualityReviewModalState createState() => _QualityReviewModalState();
}

class _QualityReviewModalState extends State<QualityReviewModal> {
  bool isLoading = false;

  Future<void> _sendQualityReview() async {
    setState(() => isLoading = true);

    try {
      // Formatear EPCs a 16 dígitos
      List<String> formattedEpcs = widget.scannedEpcs.map((epc) {
        if (epc.length < 16) {
          return epc.padLeft(16, '0');
        }
        return epc;
      }).toList();

      final response = await http.post(
        Uri.parse(
            'http://172.16.10.31/api/RfidLabel/generate-excel-from-handheld-save-inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'epcs': formattedEpcs,
          'fechaInventario': DateTime.now().toUtc().toIso8601String(),
          'formatoEtiqueta':
              'REVISION DE CALIDAD ${widget.noLogistica}', // Modificamos el formato para incluir el número de logística
          'operador': 'Embarques',
          'ubicacion': 'Tablet Zebra',
          'nombreArchivo': 'Material Separado'
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel generado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Error al generar el Excel: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Revisión de Calidad ${widget.noLogistica}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'EPCs Escaneados:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: widget.scannedEpcs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        widget.scannedEpcs[index].padLeft(16, '0'),
                        style: const TextStyle(fontFamily: 'Monospace'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Información adicional:'),
              const SizedBox(height: 8),
              _buildInfoRow('Fecha', DateTime.now().toString().split('.')[0]),
              _buildInfoRow(
                  'Formato', 'REVISION DE CALIDAD ${widget.noLogistica}'),
              _buildInfoRow('Operador', 'Embarques'),
              _buildInfoRow('Ubicación', 'Tablet Zebra'),
              _buildInfoRow('Archivo', 'Material Separado'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _sendQualityReview,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirmar y Generar Excel',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
