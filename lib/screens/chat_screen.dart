import 'package:flutter/material.dart';
import '../config.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GeminiService _gemini = GeminiService();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _gemini.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend(String text) async {
    if (!AppConfig.hasApiKey) {
      setState(() {
        _messages.add(ChatMessage(
          text:
              'No API key set. Launch with:\nflutter run --dart-define=GEMINI_API_KEY=your_key',
          role: MessageRole.error,
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, role: MessageRole.user));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      // Stateless call: only the current prompt is sent, not full history.
      // Keeps token usage flat per-turn until history mode is added later.
      final reply = await _gemini.sendMessage(text);
      setState(() {
        _messages.add(ChatMessage(text: reply, role: MessageRole.model));
      });
    } on GeminiException catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: e.message, role: MessageRole.error));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pegasus'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary),
              onPressed: _isSending
                  ? null
                  : () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const TypingIndicator();
                      }
                      return MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          ChatInput(onSend: _handleSend, isSending: _isSending),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              color: AppTheme.textSecondary.withOpacity(0.6), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Ask Pegasus anything',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
