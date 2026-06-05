import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/places_service.dart';
import '../services/auth_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/map_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  // 位置情報キャッシュ（起動時に1回取得）
  LatLng? _cachedLocation;
  List<String> _quickReplies = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _cachedLocation = await PlacesService.getCurrentLocation();
    debugPrint('位置情報: ${_cachedLocation?.latitude}, ${_cachedLocation?.longitude}');
    if (mounted && _cachedLocation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('位置情報取得: ${_cachedLocation!.latitude.toStringAsFixed(4)}, ${_cachedLocation!.longitude.toStringAsFixed(4)}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    setState(() => _isInitialLoading = false);
  }

  Future<void> _sendMessage([String? override]) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (override == null) _controller.clear();
    setState(() {
      _quickReplies = [];
    });

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: AuthService.currentUserId ?? '',
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await ChatService.sendMessage(
        text, _messages,
        lat: _cachedLocation?.latitude,
        lng: _cachedLocation?.longitude,
      );

      final meta = <String, dynamic>{};
      if (response.hasPrediction) meta['regret_prediction'] = response.regretPrediction;
      if (response.map != null) meta['map'] = response.map;

      final assistantMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: AuthService.currentUserId ?? '',
        role: 'assistant',
        content: response.message,
        decisionContext: response.decision,
        metadata: meta.isEmpty ? null : meta,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(assistantMessage);
        _isLoading = false;
        _quickReplies = response.quickReplies;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('RegretLens'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.textSecondary),
              onPressed: () => setState(() {
                _messages.clear();
                _quickReplies = [];
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildWelcome()
                    : _buildMessageList(),
          ),
          if (_quickReplies.isNotEmpty) _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _quickReplies.map((text) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _sendMessage(text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.4)),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.accentOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentOrange, width: 3),
                ),
                child: Center(child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppTheme.accentOrange, shape: BoxShape.circle),
                )),
              )),
            ),
            const SizedBox(height: 24),
            const SelectableText('RegretLens', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            SelectableText('迷ったら、まず話してみよう', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
            const SizedBox(height: 32),
            _buildSuggestion('ランチ何にしようか迷ってる', Icons.restaurant_outlined),
            _buildSuggestion('Amazonでこれ買おうか悩んでる', Icons.shopping_bag_outlined),
            _buildSuggestion('転職しようか考え中', Icons.work_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestion(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _sendMessage(text),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Icon(icon, size: 20, color: AppTheme.accentOrange),
              const SizedBox(width: 12),
              Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator();
        final msg = _messages[index];
        final map = msg.mapData;
        if (map != null && map['places'] != null) {
          final places = List<Map<String, dynamic>>.from(map['places'] as List);
          final center = map['center'] as Map<String, dynamic>;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatBubble(message: msg),
              if (places.isNotEmpty)
                StoreMapWidget(
                  centerLat: (center['lat'] as num).toDouble(),
                  centerLng: (center['lng'] as num).toDouble(),
                  places: places,
                ),
            ],
          );
        }
        return ChatBubble(message: msg);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
        child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3), width: 7, height: 7,
          decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.4), shape: BoxShape.circle),
        ))),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: '迷っていることを聞いてみる...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.accentOrange)),
            filled: true, fillColor: AppTheme.bgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          maxLines: 4, minLines: 1,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendMessage(),
        )),
        const SizedBox(width: 8),
        Container(
          decoration: const BoxDecoration(color: AppTheme.accentOrange, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
            onPressed: _isLoading ? null : () => _sendMessage(),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
