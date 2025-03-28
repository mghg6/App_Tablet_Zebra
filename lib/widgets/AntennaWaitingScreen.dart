import 'package:flutter/material.dart';
import 'dart:async';

class AntennaWaitingScreen extends StatefulWidget {
  final String logisticaNumber;
  final String carrilNumber;
  final String clienteName;
  final String operadorName;

  const AntennaWaitingScreen({
    Key? key,
    required this.logisticaNumber,
    required this.carrilNumber,
    required this.clienteName,
    required this.operadorName,
  }) : super(key: key);

  @override
  _AntennaWaitingScreenState createState() => _AntennaWaitingScreenState();
}

class _AntennaWaitingScreenState extends State<AntennaWaitingScreen>
    with SingleTickerProviderStateMixin {
  bool antenasHabilitadas = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Configurar la animación pulsante
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Simular la habilitación de antenas después de 5 segundos
    _timer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          antenasHabilitadas = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtener el padding del sistema para evitar superposición con la barra de navegación
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return WillPopScope(
      onWillPop: () async =>
          false, // Prevenir que el usuario regrese con el botón atrás
      child: Scaffold(
        body: SafeArea(
          // Con bottom: false para manejar manualmente el padding inferior
          bottom: false,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: antenasHabilitadas
                    ? [Colors.green.shade100, Colors.green.shade200]
                    : [Colors.blue.shade100, Colors.blue.shade200],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                // No necesitamos padding top porque SafeArea ya lo maneja
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 24),

                  // Logística e información del cliente
                  _buildInfoCard(),

                  SizedBox(height: 40),

                  // Icono animado de espera o verificación
                  antenasHabilitadas
                      ? _buildSuccessIcon()
                      : _buildWaitingAnimation(),

                  SizedBox(height: 32),

                  // Mensaje principal
                  Text(
                    antenasHabilitadas
                        ? "¡ANTENAS HABILITADAS!"
                        : "ESPERANDO A QUE SE HABILITEN LAS ANTENAS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: antenasHabilitadas
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                      letterSpacing: 1.2,
                    ),
                  ),

                  SizedBox(height: 16),

                  // Mensaje secundario
                  Text(
                    antenasHabilitadas
                        ? "Puedes comenzar la carga en el carril ${widget.carrilNumber}"
                        : "Por favor espere mientras se preparan las antenas para la carga en el carril ${widget.carrilNumber}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: antenasHabilitadas
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),

                  Spacer(),

                  // Botón de acción (solo visible cuando las antenas están habilitadas)
                  if (antenasHabilitadas)
                    Container(
                      width: double.infinity,
                      // Agregar padding adicional para evitar la barra de navegación
                      margin: EdgeInsets.only(bottom: 32 + bottomPadding),
                      child: Column(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            onPressed: _showCompletionDialog,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  "COMENZAR CARGA",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Presiona el botón para continuar con el proceso",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      // Agregar padding adicional para evitar la barra de navegación
                      margin: EdgeInsets.only(bottom: 32 + bottomPadding),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade700,
                            ),
                            strokeWidth: 4,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Esto puede tomar unos momentos...",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping,
                color: antenasHabilitadas
                    ? Colors.green.shade700
                    : Colors.blue.shade700,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                "Logística #${widget.logisticaNumber}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: antenasHabilitadas
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            thickness: 1,
            color: Colors.grey.shade200,
          ),
          _buildInfoRow(
            icon: Icons.business,
            label: "Cliente",
            value: widget.clienteName,
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.person,
            label: "Operador",
            value: widget.operadorName,
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.confirmation_number,
            label: "Carril Asignado",
            value: widget.carrilNumber,
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isHighlighted
              ? (antenasHabilitadas
                  ? Colors.green.shade700
                  : Colors.blue.shade700)
              : Colors.grey.shade700,
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: isHighlighted
                    ? (antenasHabilitadas
                        ? Colors.green.shade700
                        : Colors.blue.shade700)
                    : Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaitingAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue.shade300,
                width: 3,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.wifi_tethering,
                size: 60,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green.shade300,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green.shade600,
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Proceso de carga iniciado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continúa con este proceso en la pantalla de carril y el dashboard para monitoreo.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logística #${widget.logisticaNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            'Carril ${widget.carrilNumber}',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Entendido'),
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar de vuelta a la pantalla principal de logísticas
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }
}
