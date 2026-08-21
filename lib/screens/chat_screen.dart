import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/chat_input.dart';
import '../widgets/hover_glow.dart';
import '../widgets/message_bubble.dart';
import '../widgets/side_panel.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GeminiService _gemini = GeminiService();
  final StorageService _storage = StorageService();
  final ScrollController _scrollController = ScrollController();
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  List<ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _gemini.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final list = await _storage.getConversations();
    setState(() => _conversations = list);
    if (list.isNotEmpty) {
      await _openConversation(list.first.id);
    }
  }

  Future<void> _openConversation(String id) async {
    final convo = _conversations.firstWhere((c) => c.id == id);
    final msgs = await _storage.getMessages(id);
    setState(() {
      _activeConversation = convo;
      _messages = msgs;
    });
    _scrollToBottom();
  }

  void _startNewChat() {
    setState(() {
      _activeConversation = null;
      _messages = [];
    });
  }

  Future<void> _deleteConversation(String id) async {
    await _storage.deleteConversation(id);
    final wasActive = _activeConversation?.id == id;
    await _loadConversations();
    if (wasActive) _startNewChat();
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

  Future<void> _handleSend(String text, Attachment? attachment) async {
    if (!AppConfig.hasApiKey) {
      setState(() {
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          conversationId: _activeConversation?.id ?? '',
          text:
              'No API key set. Launch with:\nflutter run --dart-define=GEMINI_API_KEY=your_key',
          role: MessageRole.error,
        ));
      });
      _scrollToBottom();
      return;
    }

    Conversation? convo = _activeConversation;
    ChatMessage? userMsg;
    List<ChatMessage> priorHistory = [];

    try {
      // Lazily create a conversation on first message so empty chats never
      // clutter the side panel.
      convo ??= Conversation(
        id: _uuid.v4(),
        title: text.length > 40 ? '${text.substring(0, 40)}...' : text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (_activeConversation == null) {
        await _storage.saveConversation(convo);
        setState(() {
          _activeConversation = convo;
          _conversations = [convo!, ..._conversations];
        });
      }

      userMsg = ChatMessage(
        id: _uuid.v4(),
        conversationId: convo.id,
        text: text,
        role: MessageRole.user,
        attachmentName: attachment?.name,
        attachmentMimeType: attachment?.mimeType,
      );
      await _storage.saveMessage(userMsg);

      priorHistory = List<ChatMessage>.from(_messages);

      setState(() {
        _messages.add(userMsg!);
        _isSending = true;
      });
      _scrollToBottom();
    } catch (e) {
      // A failure here (e.g. a local storage/plugin issue) must never
      // vanish silently — show it immediately, even before we've tried
      // contacting the API at all.
      setState(() {
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          conversationId: convo?.id ?? '',
          text: 'Could not send message: $e',
          role: MessageRole.error,
        ));
      });
      _scrollToBottom();
      return;
    }

    final modelMsgId = _uuid.v4();
    var accumulated = '';

    try {
      final stream = _gemini.sendMessageStream(
        text,
        history: priorHistory,
        attachment: attachment,
      );

      await for (final chunk in stream) {
        accumulated += chunk;
        setState(() {
          final existingIndex =
              _messages.indexWhere((m) => m.id == modelMsgId);
          final updated = ChatMessage(
            id: modelMsgId,
            conversationId: convo!.id,
            text: accumulated,
            role: MessageRole.model,
          );
          if (existingIndex == -1) {
            _messages.add(updated);
          } else {
            _messages[existingIndex] = updated;
          }
        });
        _scrollToBottom();
      }

      if (accumulated.isNotEmpty) {
        final finalMsg = ChatMessage(
          id: modelMsgId,
          conversationId: convo!.id,
          text: accumulated,
          role: MessageRole.model,
        );
        await _storage.saveMessage(finalMsg);
        final updatedConvo =
            convo!.copyWith(updatedAt: DateTime.now());
        await _storage.saveConversation(updatedConvo);
        setState(() {
          _activeConversation = updatedConvo;
          _conversations = [
            updatedConvo,
            ..._conversations.where((c) => c.id != updatedConvo.id),
          ];
        });
      }
    } on GeminiException catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          conversationId: convo!.id,
          text: e.message,
          role: MessageRole.error,
        ));
      });
    } catch (e) {
      // Catch-all so a storage/plugin failure (like the Windows sqflite
      // issue this fixed) always shows as a visible error bubble instead
      // of silently discarding the message with no feedback.
      setState(() {
        _messages.add(ChatMessage(
          id: _uuid.v4(),
          conversationId: convo?.id ?? '',
          text: 'Something went wrong: $e',
          role: MessageRole.error,
        ));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: SidePanel(
          conversations: _conversations,
          activeConversationId: _activeConversation?.id,
          onSelect: _openConversation,
          onDelete: _deleteConversation,
          onNewChat: () {
            _startNewChat();
            Navigator.of(context).pop();
          },
        ),
        appBar: AppBar(
          title: const Text('Pegasus'),
          actions: [
            HoverGlow(
              borderRadius: BorderRadius.circular(20),
              child: IconButton(
                tooltip: 'New chat',
                icon: const Icon(Icons.edit_square,
                    color: AppTheme.textSecondary),
                onPressed: _startNewChat,
              ),
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
                      itemCount:
                          _messages.length + (_isSending && accumulatedEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const TypingIndicator();
                        }
                        return AnimatedEntrance(
                          key: ValueKey(_messages[index].id),
                          child: MessageBubble(message: _messages[index]),
                        );
                      },
                    ),
            ),
            ChatInput(onSend: _handleSend, isSending: _isSending),
          ],
        ),
      ),
    );
  }

  // Shows the typing indicator only before the first streamed chunk
  // arrives — once text starts appearing, the growing bubble itself is
  // the indicator, so we don't show both at once.
  bool get accumulatedEmpty =>
      _messages.isEmpty || _messages.last.role != MessageRole.model;
}

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final glow = 0.25 + (_controller.value * 0.25);
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(glow),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.textPrimary,
                  size: 36,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Ask Pegasus anything',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
