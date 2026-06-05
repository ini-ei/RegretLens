import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _patterns = [];
  Map<String, double> _categoryStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getDashboardStats(),
        ApiService.getRegretPatterns(),
        ApiService.getCategoryStats(),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _patterns = results[1] as List<Map<String, dynamic>>;
        _categoryStats = results[2] as Map<String, double>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('分析')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    Expanded(child: _StatCard(label: '意思決定', value: '${_stats['total_decisions'] ?? 0}', color: AppTheme.accentOrange)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'フィードバック', value: '${_stats['total_feedbacks'] ?? 0}', color: AppTheme.accentGreen)),
                  ]),
                  const SizedBox(height: 16),
                  _section('後悔パターン', _patterns.isEmpty
                      ? [Padding(padding: const EdgeInsets.all(8), child: SelectableText('データが溜まると表示されます', style: TextStyle(color: AppTheme.textSecondary)))]
                      : _patterns.take(5).map(_patternTile).toList()),
                  if (_categoryStats.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _section('カテゴリ別', [SizedBox(height: 200, child: _chart())]),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _patternTile(Map<String, dynamic> p) {
    final avg = (p['average_regret'] as num?)?.toDouble() ?? 0;
    final color = avg >= 4 ? AppTheme.dangerColor : avg >= 3 ? AppTheme.warningColor : AppTheme.secondaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: SelectableText(p['pattern_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
        SelectableText('${avg.toStringAsFixed(1)}/5', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _chart() {
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround, maxY: 5,
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
          final keys = _categoryStats.keys.toList();
          return v.toInt() < keys.length ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(keys[v.toInt()], style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))) : const SizedBox.shrink();
        })),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      barGroups: _categoryStats.entries.toList().asMap().entries.map((e) {
        final avg = e.value.value;
        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: avg, color: avg >= 4 ? AppTheme.dangerColor : avg >= 3 ? AppTheme.warningColor : AppTheme.accentGreen, width: 24, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))]);
      }).toList(),
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        SelectableText(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ]),
    );
  }
}
