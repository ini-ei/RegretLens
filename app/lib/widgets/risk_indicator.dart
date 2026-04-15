import 'package:flutter/material.dart';
import '../config/theme.dart';

class RiskIndicator extends StatelessWidget {
  final double score;
  final String riskLevel;
  final bool compact;

  const RiskIndicator({
    super.key,
    required this.score,
    required this.riskLevel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(riskLevel);
    final percentage = (score * 100).toInt();

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$percentage%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: score,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
                strokeWidth: 8,
              ),
            ),
            Column(
              children: [
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  riskLevel,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
