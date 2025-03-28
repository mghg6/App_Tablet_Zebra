import 'package:flutter/material.dart';
import 'package:zebra_scanner_app/widgets/AntennaWaitingScreen.dart';

class CarrilInfo {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String description;

  CarrilInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class RadioButton extends StatelessWidget {
  final String value;
  final String? groupValue;
  final Color color;

  const RadioButton({
    Key? key,
    required this.value,
    required this.groupValue,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? color : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class CarrilSelectionScreen extends StatefulWidget {
  final dynamic review;

  const CarrilSelectionScreen({Key? key, required this.review})
      : super(key: key);

  @override
  _CarrilSelectionScreenState createState() => _CarrilSelectionScreenState();
}

class _CarrilSelectionScreenState extends State<CarrilSelectionScreen> {
  String? selectedCarril;

  @override
  Widget build(BuildContext context) {
    // Obtener los paddings de seguridad para la barra de navegación y estado
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      // AppBar permanece igual
      appBar: AppBar(
        title: Text('Selección de Carril'),
      ),
      // Envolver el cuerpo en SafeArea
      body: SafeArea(
        // Configuramos bottom: false porque agregaremos un padding manual
        bottom: false,
        child: SingleChildScrollView(
          // Agregamos padding en la parte inferior para evitar la barra de navegación
          padding: EdgeInsets.only(bottom: bottomPadding + 16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoHeader(),
                SizedBox(height: 24),
                Text(
                  'Selecciona un carril para la carga:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 16),
                _buildCarrilGrid(),
                SizedBox(height: 24),
                if (selectedCarril != null)
                  Container(
                    width: double.infinity,
                    // Agregamos padding extra en la parte inferior del botón
                    margin: EdgeInsets.only(bottom: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _showConfirmationDialog,
                      child: Text(
                        'CONFIRMAR ASIGNACIÓN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300.withOpacity(0.5),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Logística #${widget.review['no_Logistica']}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.review['estatus'],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(Icons.business, 'Cliente', widget.review['cliente']),
          SizedBox(height: 8),
          _buildInfoRow(
              Icons.person, 'Operador', widget.review['operador_Separador']),
          SizedBox(height: 8),
          _buildInfoRow(Icons.support_agent, 'Auxiliar de Ventas',
              widget.review['auxiliarVentas'] ?? 'No asignado'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 18,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarrilGrid() {
    List<CarrilInfo> carriles = [
      CarrilInfo(
        id: '1',
        title: 'Carril 1',
        icon: Icons.local_shipping,
        color: Colors.blue,
        description: 'Para cargas pequeñas y medianas',
      ),
      CarrilInfo(
        id: '2',
        title: 'Carril 2',
        icon: Icons.airport_shuttle,
        color: Colors.orange,
        description: 'Para cargas medianas',
      ),
      CarrilInfo(
        id: '3',
        title: 'Carril 3',
        icon: Icons.fire_truck,
        color: Colors.purple,
        description: 'Para cargas grandes',
      ),
    ];

    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        childAspectRatio: 2.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: carriles.length,
      itemBuilder: (context, index) {
        final carril = carriles[index];
        final isSelected = selectedCarril == carril.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedCarril = carril.id;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected ? carril.color.withOpacity(0.2) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? carril.color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: carril.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: carril.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      carril.icon,
                      size: 40,
                      color: carril.color,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          carril.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? carril.color
                                : Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          carril.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RadioButton(
                    value: carril.id,
                    groupValue: selectedCarril,
                    color: carril.color,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirmar asignación'),
            ],
          ),
          content: Text(
            '¿Estás seguro que quieres asignar el Carril $selectedCarril para la logística #${widget.review['no_Logistica']}?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Confirmar'),
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar a la pantalla de espera de antenas
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AntennaWaitingScreen(
                      logisticaNumber: widget.review['no_Logistica'].toString(),
                      carrilNumber: selectedCarril!,
                      clienteName: widget.review['cliente'],
                      operadorName: widget.review['operador_Separador'],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
