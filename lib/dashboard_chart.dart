import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardChart extends StatefulWidget {
  const DashboardChart({Key? key}) : super(key: key);

  @override
  State<DashboardChart> createState() => _DashboardChartState();
}

class _DashboardChartState extends State<DashboardChart> {
  int touchedIndex = -1;
  ChartType selectedChartType = ChartType.line;

  static const Color primaryColor = Color(0xFF46707E);
  static const Color accentColor = Color(0xFF2E4A54);
  static const Color secondaryColor = Color(0xFF63A4B8);

  Widget _buildChartTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChipOption(ChartType.line, 'Línea', Icons.show_chart),
        const SizedBox(width: 8),
        _buildChipOption(ChartType.bar, 'Barras', Icons.bar_chart),
        const SizedBox(width: 8),
        _buildChipOption(ChartType.pie, 'Circular', Icons.pie_chart),
      ],
    );
  }

  Widget _buildChipOption(ChartType type, String label, IconData icon) {
    final isSelected = selectedChartType == type;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : primaryColor,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          selectedChartType = type;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: primaryColor,
      checkmarkColor: Colors.white,
      elevation: 2,
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 2,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Color(0xff68737d),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('${value.toInt()}h', style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(
                    color: Color(0xff68737d),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 5,
        minY: 0,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(1, 1),
              FlSpot(2, 4),
              FlSpot(3, 6),
              FlSpot(4, 5),
              FlSpot(5, 7),
            ],
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withOpacity(0.2),
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.4),
                  primaryColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          LineChartBarData(
            spots: const [
              FlSpot(0, 4),
              FlSpot(1, 3),
              FlSpot(2, 5),
              FlSpot(3, 4),
              FlSpot(4, 6),
              FlSpot(5, 5),
            ],
            isCurved: true,
            color: secondaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: secondaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: secondaryColor.withOpacity(0.2),
              gradient: LinearGradient(
                colors: [
                  secondaryColor.withOpacity(0.4),
                  secondaryColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(toY: 8, color: primaryColor),
              BarChartRodData(toY: 6, color: secondaryColor),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(toY: 5, color: primaryColor),
              BarChartRodData(toY: 4, color: secondaryColor),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(toY: 7, color: primaryColor),
              BarChartRodData(toY: 8, color: secondaryColor),
            ],
          ),
          BarChartGroupData(
            x: 3,
            barRods: [
              BarChartRodData(toY: 9, color: primaryColor),
              BarChartRodData(toY: 7, color: secondaryColor),
            ],
          ),
        ],
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Color(0xff68737d),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text('Q${value.toInt() + 1}', style: style),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: primaryColor,
            value: 40,
            title: '40%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: secondaryColor,
            value: 30,
            title: '30%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: accentColor,
            value: 30,
            title: '30%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget chart;
        switch (selectedChartType) {
          case ChartType.line:
            chart = _buildLineChart();
            break;
          case ChartType.bar:
            chart = _buildBarChart();
            break;
          case ChartType.pie:
            chart = _buildPieChart();
            break;
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: chart,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 50, // Fixed height for selector
                child: _buildChartTypeSelector(),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildChart(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 30, // Fixed height for legend
                child: _buildLegend(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Actual', primaryColor),
        const SizedBox(width: 20),
        _buildLegendItem('Anterior', secondaryColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

enum ChartType {
  line,
  bar,
  pie,
}
