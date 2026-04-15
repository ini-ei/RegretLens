import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/decision.dart';
import '../services/supabase_service.dart';
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
      final decisions = await SupabaseService.getDecisions();
      setState(() {
        _decisions = decisions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('意思決定履歴')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _decisions.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadDecisions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _decisions.length,
                    itemBuilder: (context, index) =>
                        _buildDecisionCard(_decisions[index]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('まだ意思決定の記録がありません'),
          Text(
            'チャットで相談すると自動的に記録されます',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(Decision decision) {
    final hasFb = decision.hasFeedback;
    final fb = hasFb ? decision.feedbacks!.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasFb
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeedbackScreen(decision: decision),
                  ),
                );
                _loadDecisions();
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      decision.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    decision.riskEmoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (decision.predictedRegretScore != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${(decision.predictedRegretScore! * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.riskColor(decision.riskLevel ?? '低'),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(decision.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                decision.decisionText,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (decision.hasUrl) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _launchUrl(decision.sourceUrl!),
                  child: Row(
                    children: [
                      Icon(
                        decision.sourceType == 'amazon'
                            ? Icons.shopping_cart
                            : Icons.location_on,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          decision.sourceUrl!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasFb) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildFbChip('後悔 ${fb!.regretScore}/5', fb.regretScore >= 4
                          ? AppTheme.dangerColor
                          : fb.regretScore >= 3
                              ? AppTheme.warningColor
                              : AppTheme.secondaryColor),
                      const SizedBox(width: 8),
                      _buildFbChip('満足 ${fb.satisfactionScore}/5', fb.satisfactionScore >= 4
                          ? AppTheme.secondaryColor
                          : fb.satisfactionScore <= 2
                              ? AppTheme.dangerColor
                              : AppTheme.warningColor),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review, size: 14, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text(
                        'フィードバックを記録',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFbChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${date.month}/${date.day}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
