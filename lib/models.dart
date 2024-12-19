import 'package:http/http.dart' as http;
import 'dart:convert';

class Producto {
  final String urlImagen;
  final String fecha;
  final String area;
  final String claveProducto;
  final String nombreProducto;
  final String pesoBruto;
  final String pesoNeto;
  final String pesoTarima;
  final String piezas;
  final String uom;
  final String fechaEntrada;
  final String productPrintCard;
  final String horaEntrada;

  Producto({
    required this.urlImagen,
    required this.fecha,
    required this.area,
    required this.claveProducto,
    required this.nombreProducto,
    required this.pesoBruto,
    required this.pesoNeto,
    required this.pesoTarima,
    required this.piezas,
    required this.uom,
    required this.fechaEntrada,
    required this.productPrintCard,
    required this.horaEntrada,
  });

  // Método auxiliar para obtener la URL de la imagen en base a `productPrintCard`
  static Future<String> obtenerUrlImagen(String? productPrintCard) async {
    String defaultUrl =
        'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';
    if (productPrintCard == null) {
      return defaultUrl;
    }
    try {
      final response = await http.get(
        Uri.parse("http://172.16.10.31/api/Image/$productPrintCard"),
      );
      if (response.statusCode == 200) {
        final imageData = jsonDecode(response.body);
        return imageData['imageBase64'] ?? defaultUrl;
      } else {
        print("Error al obtener la imagen: ${response.statusCode}");
        return defaultUrl;
      }
    } catch (error) {
      print("Error al cargar la imagen: $error");
      return defaultUrl;
    }
  }

  // Factory method for JSON deserialization
  static Future<Producto> fromJson(Map<String, dynamic> json) async {
    String urlImagen = await obtenerUrlImagen(json['productPrintCard']);
    return Producto(
      urlImagen: urlImagen,
      fecha: json['fecha'] ?? '',
      area: json['area'] ?? '',
      claveProducto: json['claveProducto'] ?? '',
      nombreProducto: json['nombreProducto'] ?? '',
      pesoBruto: json['pesoBruto']?.toString() ?? '',
      pesoNeto: json['pesoNeto']?.toString() ?? '',
      pesoTarima: json['pesoTarima']?.toString() ?? '',
      piezas: json['piezas']?.toString() ?? '',
      uom: json['uom'] ?? '',
      fechaEntrada: json['createdAt'] ?? DateTime.now().toString(),
      productPrintCard: json['productPrintCard'] ?? '',
      horaEntrada: json['horaEntrada'] ??
          "${DateTime.now().hour}:${DateTime.now().minute}",
    );
  }

  // Método toJson para convertir el objeto Producto a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'urlImagen': urlImagen,
      'fecha': fecha,
      'area': area,
      'claveProducto': claveProducto,
      'nombreProducto': nombreProducto,
      'pesoBruto': pesoBruto,
      'pesoNeto': pesoNeto,
      'pesoTarima': pesoTarima,
      'piezas': piezas,
      'uom': uom,
      'fechaEntrada': fechaEntrada,
      'productPrintCard': productPrintCard,
      'horaEntrada': horaEntrada,
    };
  }
}
