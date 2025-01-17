import 'package:flutter/material.dart';
import 'dashboard_chart.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color textPrimaryColor = Color(0xFF0D0D0D);
  static const Color cardShadowColor = Color(0x33000000);

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Resumen de Actividades',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Aquí encontrarás un resumen visual de tus datos recientes.',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF757575),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required Widget content,
    EdgeInsets? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {}, // Preparado para futura interactividad
            splashColor: Colors.grey.withOpacity(0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return _buildCard(
      title: 'Gráfico de Actividad',
      content: SizedBox(
        height: 300, // Altura fija para el gráfico
        child: DashboardChart(),
      ),
    );
  }

  Widget _buildStatsCard() {
    return _buildCard(
      title: 'Estadísticas Detalladas',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatItem(
            icon: Icons.trending_up,
            title: 'Productividad',
            value: '85%',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildStatItem(
            icon: Icons.inventory,
            title: 'Inventario Total',
            value: '1,234',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildStatItem(
            icon: Icons.local_shipping,
            title: 'Envíos Pendientes',
            value: '45',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF616161),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Implementar actualización de datos
            await Future.delayed(const Duration(seconds: 1));
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildChartCard(),
                    _buildStatsCard(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
