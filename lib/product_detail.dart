import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:typed_data';

class ProductDetail extends StatefulWidget {
  @override
  _ProductDetailState createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  late List<Producto> productos = [];
  Producto? productoSeleccionado;
  String nombreOperador = "Sin operador asociado";
  bool statusOk = false;
  bool registradoEnSAP = false;
  DateTime currentTime = DateTime.now();
  Timer? _timer;

  // SignalR configuration
  HubConnection? _hubConnection; // Cambiado a tipo nullable
  final String _signalRUrl = "http://172.16.10.31:86/message";
  final String groupName = "EntradaPT"; // Nombre del grupo de SignalR

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 1), () {
      _connectWithLongPolling();
    });
    _startClock();
  }

  void _handleStatusCheck(Map<String, dynamic> data) {
    setState(() {
      // Define las condiciones para estado "OK" o "Error"
      statusOk = data['epc'] != null && data['epc'].isNotEmpty;
      registradoEnSAP = data['operadorEPC'] != 'sin operador asociado';
    });
  }

  // Conectar solo con LongPolling
  Future<void> _connectWithLongPolling() async {
    try {
      print("Intentando configurar y conectar a SignalR con LongPolling...");

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            _signalRUrl,
            options: HttpConnectionOptions(
              skipNegotiation: false,
              transport: HttpTransportType.LongPolling,
            ),
          )
          .build();

      // Configurar evento de recepción de datos
      _hubConnection?.on("sendEpc", (arguments) async {
        print("Evento sendEpc recibido con argumentos: $arguments");
        if (arguments != null && arguments.isNotEmpty) {
          final data = arguments[0] as Map<String, dynamic>;

          // Imprimir todos los datos recibidos en consola
          print("Datos completos recibidos del evento sendEpc:");
          data.forEach((key, value) {
            print("$key: $value");
          });
          _handleStatusCheck(data);

          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Nueva Tarima Detectada"),
                  content: Text(
                      "Se ha detectado una nueva tarima con EPC: ${data['epc']}."),
                );
              },
            );

            // Cerrar el diálogo después de 3 segundos
            Future.delayed(Duration(seconds: 3), () {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }

          // Extraer el valor de `epc` y cargar detalles completos del producto
          String epc = data['epc'] ?? '';
          if (epc.isNotEmpty) {
            await _loadProductDetails(epc);
          } else {
            print("EPC no disponible en los datos recibidos");
          }
        }
      });

      await _hubConnection?.start();
      print("Conectado a SignalR con LongPolling");

      if (_hubConnection?.state == HubConnectionState.Connected) {
        await _hubConnection!.invoke("JoinGroup", args: [groupName]);
        print("Unido al grupo: $groupName");
      }
    } catch (error) {
      print("Error al conectar con LongPolling: $error");

      // Intentar reconectar después de un retraso
      Future.delayed(Duration(seconds: 5), () {
        print("Reintentando conexión...");
        _connectWithLongPolling();
      });
    }
  }

// Nueva función para cargar detalles completos del producto
  Future<void> _loadProductDetails(String epc) async {
    try {
      print("Cargando detalles completos para EPC: $epc");
      final response =
          await http.get(Uri.parse("http://172.16.10.31/api/socket/$epc"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Datos de producto completos recibidos: $data");

        // Obtener la imagen según el `productPrintCard`
        String urlImagen =
            'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';
        if (data['productPrintCard'] != null) {
          try {
            final imageResponse = await http.get(
              Uri.parse(
                  "http://172.16.10.31/api/Image/${data['productPrintCard']}"),
            );
            if (imageResponse.statusCode == 200) {
              final imageData = jsonDecode(imageResponse.body);
              urlImagen = imageData['imageBase64'] ?? urlImagen;
              print("URL de la imagen obtenida: $urlImagen");
            } else {
              print("Error al obtener la imagen: ${imageResponse.statusCode}");
            }
          } catch (imageError) {
            print("Error al cargar la imagen: $imageError");
          }
        }

        // Crear objeto Producto con los datos recibidos
        final producto = Producto(
          urlImagen: urlImagen,
          fecha: data['fecha'] ?? '',
          area: data['area'] ?? '',
          claveProducto: data['claveProducto'] ?? '',
          nombreProducto: data['nombreProducto'] ?? '',
          pesoBruto: data['pesoBruto']?.toString() ?? '',
          pesoNeto: data['pesoNeto']?.toString() ?? '',
          pesoTarima: data['pesoTarima']?.toString() ?? '',
          piezas: data['piezas']?.toString() ?? '',
          uom: data['uom'] ?? '',
          fechaEntrada: data['createdAt'] ?? DateTime.now().toString(),
          productPrintCard: data['productPrintCard'] ?? '',
          horaEntrada: "${DateTime.now().hour}:${DateTime.now().minute}",
        );

        setState(() {
          productos.insert(0, producto);
          productoSeleccionado = producto;
        });

        print("Producto cargado con EPC: ${producto.claveProducto}");
      } else {
        print(
            "Error al cargar datos de producto: código de estado ${response.statusCode}");
      }
    } catch (error) {
      print("Error al cargar datos de producto: $error");
    }
  }

  // Función para cerrar la conexión de forma segura
  Future<void> _closeConnection() async {
    if (_hubConnection != null) {
      await _hubConnection?.stop();
      print("Conexión cerrada correctamente.");
    }
  }

  // Start the clock with a periodic update
  void _startClock() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> updateStatus(String epc, int newStatus) async {
    try {
      print("Actualizando estado para EPC: $epc");
      final response = await http.put(
        Uri.parse("http://172.16.10.31/api/RfidLabel/UpdateStatusByRFID/$epc"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );

      if (mounted) {
        setState(() {
          statusOk = response.statusCode == 200;
        });
        print("Estado actualizado: ${statusOk ? "OK" : "Fallido"}");
      }
    } catch (error) {
      print("Error al actualizar el estado: $error");
      if (mounted) {
        setState(() => statusOk = false);
      }
    }
  }

  Future<void> fetchOperadorInfo(String epcOperador) async {
    try {
      print(
          "Obteniendo información del operador para EPC operador: $epcOperador");
      final response = await http.get(
        Uri.parse("http://172.16.10.31/api/OperadoresRFID/$epcOperador"),
      );

      if (mounted) {
        setState(() {
          nombreOperador = response.statusCode == 200
              ? jsonDecode(response.body)['nombreOperador']
              : "Operador no encontrado";
        });
        print("Nombre del operador obtenido: $nombreOperador");
      }
    } catch (error) {
      print("Error al obtener el operador: $error");
      if (mounted) {
        setState(() => nombreOperador = "Error al obtener operador");
      }
    }
  }

  Future<void> loadData(String epc) async {
    try {
      print("Cargando datos para EPC: $epc");
      final response =
          await http.get(Uri.parse("http://172.16.10.31/api/socket/$epc"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Imprimir todos los datos recibidos en consola
        print("Datos completos recibidos de la API para EPC $epc:");
        data.forEach((key, value) {
          print("$key: $value");
        });

        // Obtener la imagen según el `productPrintCard`
        String urlImagen =
            'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png';
        if (data['productPrintCard'] != null) {
          try {
            final imageResponse = await http.get(
              Uri.parse(
                  "http://172.16.10.31/api/Image/${data['productPrintCard']}"),
            );
            if (imageResponse.statusCode == 200) {
              final imageData = jsonDecode(imageResponse.body);
              urlImagen = imageData['imageBase64'] ?? urlImagen;
              print("URL de la imagen obtenida: $urlImagen");
            } else {
              print("Error al obtener la imagen: ${imageResponse.statusCode}");
            }
          } catch (imageError) {
            print("Error al cargar la imagen: $imageError");
          }
        }

        final producto = Producto(
          urlImagen: urlImagen,
          fecha: data['fecha'] ?? '',
          area: data['area'] ?? '',
          claveProducto: data['claveProducto'] ?? '',
          nombreProducto: data['nombreProducto'] ?? '',
          pesoBruto: data['pesoBruto']?.toString() ?? '',
          pesoNeto: data['pesoNeto']?.toString() ?? '',
          pesoTarima: data['pesoTarima']?.toString() ?? '',
          piezas: data['piezas']?.toString() ?? '',
          uom: data['uom'] ?? '',
          fechaEntrada: data['createdAt'] ?? DateTime.now().toString(),
          productPrintCard: data['productPrintCard'] ?? '',
          horaEntrada: "${DateTime.now().hour}:${DateTime.now().minute}",
        );

        setState(() {
          productos.insert(0, producto);
          productoSeleccionado = producto;
        });

        print("Producto cargado con EPC: ${producto.claveProducto}");
      } else {
        print("Error al cargar datos: código de estado ${response.statusCode}");
      }
    } catch (error) {
      print("Error al cargar datos: $error");
    }
  }

  Future<void> extraInfo(String epc) async {
    try {
      print("Registrando información extra para EPC: $epc");
      final response = await http.post(
        Uri.parse("http://172.16.10.31/api/ProdExtraInfo/EntradaAlmacen/$epc"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (mounted) {
        setState(() {
          registradoEnSAP = response.statusCode == 200;
        });
        print("Registro en SAP: ${registradoEnSAP ? "Exitoso" : "Fallido"}");
      }
    } catch (error) {
      print("Error al registrar en SAP: $error");
      if (mounted) {
        setState(() => registradoEnSAP = false);
      }
    }
  }

  Future<void> registroAntenas(String epc, String epcOperador) async {
    try {
      print("Registrando antena para EPC: $epc y EPC operador: $epcOperador");
      await http.post(
        Uri.parse(
            "http://172.16.10.31/api/ProdRegistroAntenas?epcOperador=$epcOperador&epc=$epc"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      print("Registro de antena completado");
    } catch (error) {
      print("Error al registrar antenas: $error");
    }
  }

  Widget buildImageFromBase64(String base64Image) {
    // Verificar si el valor de base64Image contiene datos válidos en base64
    if (base64Image.startsWith("data:image")) {
      try {
        // Remover el prefijo y decodificar la cadena base64
        final decodedBytes = base64Decode(base64Image.split(',')[1]);
        return Image.memory(
          decodedBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // En caso de error, mostrar imagen por defecto
            return Image.network(
              'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png',
              fit: BoxFit.cover,
            );
          },
        );
      } catch (e) {
        print("Error al decodificar base64: $e");
      }
    }

    // Si el base64Image no es válido o es nulo, mostrar imagen por defecto
    return Image.network(
      'https://calibri.mx/bioflex/wp-content/uploads/2024/03/standup_pouch.png',
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lista de productos
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Color(0xFF46707E),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.network(
                        "https://darsis.us/bioflex/wp-content/uploads/2023/05/logo_b.png",
                        width: 200,
                        height: 50,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: productos.length,
                          itemBuilder: (context, index) {
                            final producto = productos[index];
                            return GestureDetector(
                              onTap: () async {
                                // Carga asincrónica del producto seleccionado
                                final productoConImagen =
                                    await Producto.fromJson(producto.toJson());
                                setState(() {
                                  productoSeleccionado = productoConImagen;
                                });
                              },
                              child: Card(
                                margin: EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Área: ${producto.area}",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          )),
                                      SizedBox(height: 8),
                                      Text(
                                          "Clave de Producto: ${producto.claveProducto}"),
                                      Text(
                                          "Producto: ${producto.nombreProducto}"),
                                      Text(
                                          "Hora de Entrada: ${productoSeleccionado?.horaEntrada ?? 'N/A'}"),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 20),
              // Detalles del producto seleccionado
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: productoSeleccionado != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header con título y fecha
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "ENTRADA PT-1",
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF46707E),
                                  ),
                                ),
                                Text(
                                  "${currentTime.toLocal()}".split(' ')[0],
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            Divider(thickness: 1, color: Colors.grey[300]),
                            SizedBox(height: 20),
                            Text(
                              'DETALLES DEL PRODUCTO',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Imagen del Producto
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Color(0xFF46707E),
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: buildImageFromBase64(
                                      productoSeleccionado!.urlImagen),
                                ),
                                SizedBox(width: 20),
                                // Status Checks
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _statusCheckRow(
                                      "Status",
                                      statusOk
                                          ? "✔️ OK"
                                          : "❌ Error", // Muestra el estado en función de statusOk
                                    ),
                                    SizedBox(height: 8),
                                    _statusCheckRow(
                                      "Registrado en SAP",
                                      registradoEnSAP
                                          ? "✔️ OK"
                                          : "❌ No registrado", // Muestra el estado en función de registradoEnSAP
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Expanded(
                              child: SingleChildScrollView(
                                child: GridView.count(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 8,
                                  childAspectRatio:
                                      3, // Ajustar la proporción para filas más altas
                                  children: [
                                    _detailField(
                                      "PRODUCTO",
                                      productoSeleccionado?.nombreProducto ??
                                          'N/A',
                                    ),
                                    _detailField(
                                      "PESO NETO",
                                      productoSeleccionado?.pesoNeto ?? 'N/A',
                                    ),
                                    _detailField(
                                      "PIEZAS",
                                      productoSeleccionado?.piezas ?? 'N/A',
                                    ),
                                    _detailField(
                                      "UNIDAD DE MEDIDA",
                                      productoSeleccionado?.uom ?? 'N/A',
                                    ),
                                    _detailField(
                                      "PRINTCARD",
                                      productoSeleccionado?.productPrintCard ??
                                          'N/A',
                                    ),
                                    _detailField(
                                      "OPERADOR",
                                      nombreOperador,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            "Selecciona un producto para ver los detalles",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 5),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.grey[100],
          ),
          child: AutoSizeText(
            value,
            maxLines: 1, // Limitar el texto a una línea
            minFontSize: 10, // Reducir el tamaño mínimo del texto
            overflow:
                TextOverflow.ellipsis, // Agregar "..." si el texto es muy largo
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCheckRow(String label, String status) {
    return Row(
      children: [
        Text(
          "$label:",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(width: 10),
        Text(
          status,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: status == "✔️ OK"
                ? Colors.green
                : Colors.red, // Verde para OK, rojo para error
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
