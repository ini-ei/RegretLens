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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('フィードバック')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: SelectableText(widget.decision.category, style: const TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              SelectableText(widget.decision.decisionText, style: const TextStyle(color: AppTheme.textPrimary)),
            ]),
          ),
          const SizedBox(height: 24),
          _slider('後悔度', _regretScore, (v) => setState(() => _regretScore = v), _regretScore >= 4 ? AppTheme.dangerColor : _regretScore >= 3 ? AppTheme.warningColor : AppTheme.secondaryColor),
          const SizedBox(height: 20),
          _slider('満足度', _satisfactionScore, (v) => setState(() => _satisfactionScore = v), _satisfactionScore >= 4 ? AppTheme.secondaryColor : _satisfactionScore <= 2 ? AppTheme.dangerColor : AppTheme.warningColor),
          const SizedBox(height: 16),
          SwitchListTile(title: const SelectableText('もう一度選べるなら変える？'), value: _wouldChange, activeColor: AppTheme.accentOrange, onChanged: (v) => setState(() => _wouldChange = v), contentPadding: EdgeInsets.zero),
          const SizedBox(height: 12),
          const SelectableText('タイミング', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: ['直後', '1日後', '1週間後', '1ヶ月後'].map((t) => ChoiceChip(label: Text(t), selected: _feedbackTiming == t, onSelected: (_) => setState(() => _feedbackTiming = t))).toList()),
          const SizedBox(height: 16),
          TextField(controller: _reasonsController, decoration: const InputDecoration(labelText: '後悔の理由（カンマ区切り）'), maxLines: 2),
          const SizedBox(height: 12),
          TextField(controller: _textController, decoration: const InputDecoration(labelText: '振り返りメモ'), maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? '保存中...' : '保存'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        SelectableText(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        SelectableText('${value.toInt()}/5', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
      ]),
      Slider(value: value, min: 1, max: 5, divisions: 4, activeColor: color, onChanged: onChanged),
    ]);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final reasons = _reasonsController.text.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
      await Supabase.instance.client.functions.invoke('feedback', body: {
        'decision_id': widget.decision.id,
        'regret_score': _regretScore.toInt(),
        'satisfaction_score': _satisfactionScore.toInt(),
        'regret_reasons': reasons,
        'would_change': _wouldChange,
        'feedback_timing': _feedbackTiming,
        'feedback_text': _textController.text.isEmpty ? null : _textController.text,
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました'))); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() { _reasonsController.dispose(); _textController.dispose(); super.dispose(); }
}
