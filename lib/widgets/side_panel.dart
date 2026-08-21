import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';
import '../theme/app_theme.dart';

class SidePanel extends StatelessWidget {
  final List<Conversation> conversations;
  final String? activeConversationId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onNewChat;

  const SidePanel({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.onSelect,
    required this.onDelete,
    required this.onNewChat,
  });

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    return isToday ? DateFormat.Hm().format(d) : DateFormat.MMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: 300,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bgTop.withOpacity(0.92),
                  AppTheme.bgBottom.withOpacity(0.96),
                ],
              ),
              border: const Border(
                right: BorderSide(color: AppTheme.glassBorder),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'History',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'New chat',
                          icon: const Icon(Icons.add_rounded,
                              color: AppTheme.accent),
                          onPressed: onNewChat,
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  Expanded(
                    child: conversations.isEmpty
                        ? const Center(
                            child: Text(
                              'No conversations yet',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: conversations.length,
                            itemBuilder: (context, index) {
                              final c = conversations[index];
                              final isActive = c.id == activeConversationId;
                              return Dismissible(
                                key: ValueKey(c.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppTheme.errorBubble,
                                  child: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.white),
                                ),
                                onDismissed: (_) => onDelete(c.id),
                                child: ListTile(
                                  selected: isActive,
                                  selectedTileColor:
                                      Colors.white.withOpacity(0.06),
                                  leading: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 18,
                                  ),
                                  title: Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatDate(c.updatedAt),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  onTap: () {
                                    onSelect(c.id);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
