import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final Color bg = message.isError
        ? AppTheme.errorBubble
        : (isUser ? AppTheme.userBubble : AppTheme.modelBubble);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: GlassContainer(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          fillColor: bg,
          blurSigma: 12,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasAttachment)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file_rounded,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            message.attachmentName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                MarkdownBody(
                  data: message.text.isEmpty ? ' ' : message.text,
                  selectable: false,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                    code: TextStyle(
                      backgroundColor: Colors.black.withOpacity(0.25),
                      color: const Color(0xFFCFE0FF),
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    listBullet: const TextStyle(color: AppTheme.textPrimary),
                    strong: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
