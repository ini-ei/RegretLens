import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/decision.dart';
import '../services/api_service.dart';
import 'feedback_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Decision> _decisions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDecisions();
  }

  Future<void> _loadDecisions() async {
    try {
      final decisions = await ApiService.getDecisions();
      setState(() { _decisions = decisions; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('記録')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _decisions.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.list_alt, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  SelectableText('チャットで相談すると自動で記録されます', style: TextStyle(color: AppTheme.textSecondary)),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadDecisions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _decisions.length,
                    itemBuilder: (_, i) => _card(_decisions[i]),
                  ),
                ),
    );
  }

  Widget _card(Decision d) {
    final hasFb = d.hasFeedback;
    final fb = hasFb ? d.feedbacks!.first : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasFb ? null : () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackScreen(decision: d)));
          _loadDecisions();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: SelectableText(d.category, style: const TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
              ),
              if (d.predictedRegretScore != null) ...[
                const SizedBox(width: 8),
                SelectableText('${d.riskEmoji} ${(d.predictedRegretScore! * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.riskColor(d.riskLevel ?? '低'))),
              ],
              const Spacer(),
              SelectableText(_formatDate(d.createdAt), style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 8),
            SelectableText(d.decisionText, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary), maxLines: 2),
            if (d.hasUrl) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(d.sourceUrl!), mode: LaunchMode.externalApplication),
                child: SelectableText(d.sourceUrl!, style: const TextStyle(fontSize: 12, color: AppTheme.accentBlue, decoration: TextDecoration.underline), maxLines: 1),
              ),
            ],
            if (hasFb) ...[
              const SizedBox(height: 8),
              Row(children: [
                _chip('後悔 ${fb!.regretScore}/5', fb.regretScore >= 4 ? AppTheme.dangerColor : fb.regretScore >= 3 ? AppTheme.warningColor : AppTheme.secondaryColor),
                const SizedBox(width: 8),
                _chip('満足 ${fb.satisfactionScore}/5', fb.satisfactionScore >= 4 ? AppTheme.secondaryColor : fb.satisfactionScore <= 2 ? AppTheme.dangerColor : AppTheme.warningColor),
              ]),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText('タップしてフィードバック', style: TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: SelectableText(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${date.month}/${date.day}';
  }
}
