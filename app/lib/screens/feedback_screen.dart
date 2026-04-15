import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/decision.dart';

class FeedbackScreen extends StatefulWidget {
  final Decision decision;

  const FeedbackScreen({super.key, required this.decision});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  double _regretScore = 3;
  double _satisfactionScore = 3;
  bool _wouldChange = false;
  String _feedbackTiming = '直後';
  final _reasonsController = TextEditingController();
  final _textController = TextEditingController();
  bool _isSaving = false;

  final _timingOptions = ['直後', '1日後', '1週間後', '1ヶ月後'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('フィードバック')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 元の意思決定情報
            Card(
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
                            widget.decision.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.decision.predictedRegretScore != null)
                          Text(
                            '予測: ${(widget.decision.predictedRegretScore! * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.riskColor(widget.decision.riskLevel ?? '低'),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.decision.decisionText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 後悔度スライダー
            _buildSlider(
              label: '後悔度',
              value: _regretScore,
              min: 1,
              max: 5,
              lowLabel: '全く後悔なし',
              highLabel: 'とても後悔',
              color: _regretScore >= 4
                  ? AppTheme.dangerColor
                  : _regretScore >= 3
                      ? AppTheme.warningColor
                      : AppTheme.secondaryColor,
              onChanged: (v) => setState(() => _regretScore = v),
            ),
            const SizedBox(height: 20),

            // 満足度スライダー
            _buildSlider(
              label: '満足度',
              value: _satisfactionScore,
              min: 1,
              max: 5,
              lowLabel: '不満',
              highLabel: 'とても満足',
              color: _satisfactionScore >= 4
                  ? AppTheme.secondaryColor
                  : _satisfactionScore <= 2
                      ? AppTheme.dangerColor
                      : AppTheme.warningColor,
              onChanged: (v) => setState(() => _satisfactionScore = v),
            ),
            const SizedBox(height: 20),

            // もう一度選べるなら変える？
            SwitchListTile(
              title: const Text('もう一度選べるなら変える？'),
              value: _wouldChange,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => _wouldChange = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // フィードバックタイミング
            const Text('いつの時点での評価？', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _timingOptions.map((t) => ChoiceChip(
                    label: Text(t),
                    selected: _feedbackTiming == t,
                    onSelected: (_) => setState(() => _feedbackTiming = t),
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  )).toList(),
            ),
            const SizedBox(height: 20),

            // 後悔の理由
            TextField(
              controller: _reasonsController,
              decoration: const InputDecoration(
                labelText: '後悔の理由（カンマ区切り）',
                hintText: '値段が高かった, 期待外れだった',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // 自由記述
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: '振り返りメモ（任意）',
                hintText: '次回に活かしたいこと...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveFeedback,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? '保存中...' : 'フィードバックを保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String lowLabel,
    required String highLabel,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${value.toInt()}/${max.toInt()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 18,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          activeColor: color,
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(highLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Future<void> _saveFeedback() async {
    setState(() => _isSaving = true);

    try {
      final reasons = _reasonsController.text
          .split(',')
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toList();

      await Supabase.instance.client.functions.invoke(
        'feedback',
        body: {
          'decision_id': widget.decision.id,
          'regret_score': _regretScore.toInt(),
          'satisfaction_score': _satisfactionScore.toInt(),
          'regret_reasons': reasons,
          'would_change': _wouldChange,
          'feedback_timing': _feedbackTiming,
          'feedback_text': _textController.text.isEmpty ? null : _textController.text,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フィードバックを保存しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _reasonsController.dispose();
    _textController.dispose();
    super.dispose();
  }
}
