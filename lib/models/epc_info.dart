// models/epc_info.dart
class EPCInfo {
  final int id;
  final String epc;
  final String area;
  final String nombreProducto;
  final String claveProducto;
  final double pesoBruto;
  final double pesoNeto;
  final int piezas;
  final String orden;
  final String claveUnidad;
  final int status;

  EPCInfo({
    required this.id,
    required this.epc,
    required this.area,
    required this.nombreProducto,
    required this.claveProducto,
    required this.pesoBruto,
    required this.pesoNeto,
    required this.piezas,
    required this.orden,
    required this.claveUnidad,
    required this.status,
  });

  factory EPCInfo.fromJson(Map<String, dynamic> json) {
    return EPCInfo(
      id: json['id'] ?? 0,
      epc: json['epc'] ?? '',
      area: json['area'] ?? '',
      nombreProducto: json['nombreProducto'] ?? '',
      claveProducto: json['claveProducto'] ?? '',
      pesoBruto: json['pesoBruto']?.toDouble() ?? 0.0,
      pesoNeto: json['pesoNeto']?.toDouble() ?? 0.0,
      piezas: json['piezas'] ?? 0,
      orden: json['orden'] ?? '',
      claveUnidad: json['claveUnidad'] ?? '',
      status: json['status'] ?? 0,
    );
  }
}
