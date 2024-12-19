import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Color(0xFF46707E), width: 2),
          ),
          minX: 0,
          maxX: 5,
          minY: 0,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, 3),
                FlSpot(1, 1),
                FlSpot(2, 4),
                FlSpot(3, 6),
                FlSpot(4, 5),
                FlSpot(5, 7),
              ],
              isCurved: true,
              color: Color(0xFF46707E),
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: Color(0xFF46707E).withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
