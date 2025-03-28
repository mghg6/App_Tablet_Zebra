// Función auxiliar para convertir a int de forma segura
int toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    try {
      return int.parse(value);
    } catch (_) {
      try {
        return double.parse(value).toInt();
      } catch (_) {
        return 0;
      }
    }
  }
  return 0;
}

// Modelo PalletEntry
class PalletEntry {
  final int id;
  final int prodEtiquetaRFIDId;
  final int numTarima;
  final String trazabilidad;
  final String antena;
  final String fechaEntrada;
  final String? fechaAltaSAP;
  final String? fechaBajaSAP;
  final String? operadorEntrada;
  final String? operadorAltaSAP;
  final ProdEtiquetaRFID prodEtiquetaRFID;

  PalletEntry({
    required this.id,
    required this.prodEtiquetaRFIDId,
    required this.numTarima,
    required this.trazabilidad,
    required this.antena,
    required this.fechaEntrada,
    this.fechaAltaSAP,
    this.fechaBajaSAP,
    this.operadorEntrada,
    this.operadorAltaSAP,
    required this.prodEtiquetaRFID,
  });

  factory PalletEntry.fromJson(Map<String, dynamic> json) {
    return PalletEntry(
      id: toInt(json['id']),
      prodEtiquetaRFIDId: toInt(json['prodEtiquetaRFIDId']),
      numTarima: toInt(json['numTarima']),
      trazabilidad: json['trazabilidad'] ?? '',
      antena: json['antena'] ?? '',
      fechaEntrada: json['fechaEntrada'] ?? '',
      fechaAltaSAP: json['fechaAltaSAP'],
      fechaBajaSAP: json['fechaBajaSAP'],
      operadorEntrada: json['operadorEntrada'],
      operadorAltaSAP: json['operadorAltaSAP'],
      prodEtiquetaRFID:
          ProdEtiquetaRFID.fromJson(json['prodEtiquetaRFID'] ?? {}),
    );
  }
}

// Modelo ProdEtiquetaRFID
class ProdEtiquetaRFID {
  final int id;
  final String area;
  final String fecha;
  final String claveProducto;
  final String nombreProducto;
  final String claveOperador;
  final String operador;
  final String turno;
  final int pesoTarima;
  final int pesoBruto;
  final int pesoNeto;
  final int piezas;
  final String trazabilidad;
  final String orden;
  final String rfid;
  final int status;
  final String uom;
  final String createdAt;
  final int impresora;
  final String? ubicacion;
  final String claveUnidad;
  final String costo;

  ProdEtiquetaRFID({
    required this.id,
    required this.area,
    required this.fecha,
    required this.claveProducto,
    required this.nombreProducto,
    required this.claveOperador,
    required this.operador,
    required this.turno,
    required this.pesoTarima,
    required this.pesoBruto,
    required this.pesoNeto,
    required this.piezas,
    required this.trazabilidad,
    required this.orden,
    required this.rfid,
    required this.status,
    required this.uom,
    required this.createdAt,
    required this.impresora,
    this.ubicacion,
    required this.claveUnidad,
    required this.costo,
  });

  factory ProdEtiquetaRFID.fromJson(Map<String, dynamic> json) {
    return ProdEtiquetaRFID(
      id: toInt(json['id']),
      area: json['area'] ?? '',
      fecha: json['fecha'] ?? '',
      claveProducto: json['claveProducto'] ?? '',
      nombreProducto: json['nombreProducto'] ?? '',
      claveOperador: json['claveOperador'] ?? '',
      operador: json['operador'] ?? '',
      turno: json['turno'] ?? '',
      pesoTarima: toInt(json['pesoTarima']),
      pesoBruto: toInt(json['pesoBruto']),
      pesoNeto: toInt(json['pesoNeto']),
      piezas: toInt(json['piezas']),
      trazabilidad: json['trazabilidad'] ?? '',
      orden: json['orden'] ?? '',
      rfid: json['rfid'] ?? '',
      status: toInt(json['status']),
      uom: json['uom'] ?? '',
      createdAt: json['createdAt'] ?? '',
      impresora: toInt(json['impresora']),
      ubicacion: json['ubicacion'],
      claveUnidad: json['claveUnidad'] ?? '',
      costo: json['costo'] ?? '',
    );
  }
}
