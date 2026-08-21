import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';
import 'hover_glow.dart';

class ChatInput extends StatefulWidget {
  final void Function(String text, Attachment? attachment) onSend;
  final bool isSending;

  const ChatInput({
    super.key,
    required this.onSend,
    required this.isSending,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Attachment? _pendingAttachment;
  bool _isPicking = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  Future<void> _pickFile() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'md', 'csv'
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      // Keep attachments small — large files cost a lot of tokens and can
      // blow past request size limits. 4MB is a generous ceiling for a
      // chat attachment; raise it in config if you need bigger files.
      const maxBytes = 4 * 1024 * 1024;
      if (file.bytes!.length > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large — 4MB max.')),
          );
        }
        return;
      }

      final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
      setState(() {
        _pendingAttachment = Attachment(
          name: file.name,
          mimeType: mimeType,
          base64Data: base64Encode(file.bytes!),
        );
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingAttachment == null) || widget.isSending) {
      return;
    }
    widget.onSend(
      text.isEmpty ? 'Describe this file.' : text,
      _pendingAttachment,
    );
    _controller.clear();
    setState(() => _pendingAttachment = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _pendingAttachment != null
                  ? Align(
                      key: const ValueKey('attachment-chip'),
                      alignment: Alignment.centerLeft,
                      child: GlassContainer(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file_rounded,
                                size: 16, color: AppTheme.accent),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                _pendingAttachment!.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _pendingAttachment = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-attachment')),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.30),
                          blurRadius: 20,
                          spreadRadius: -2,
                        ),
                      ]
                    : [],
              ),
              child: GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                borderRadius: BorderRadius.circular(26),
                child: Row(
                  children: [
                    HoverGlow(
                      borderRadius: BorderRadius.circular(24),
                      child: IconButton(
                        onPressed: (widget.isSending || _isPicking)
                            ? null
                            : _pickFile,
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: _isPicking
                              ? AppTheme.textSecondary
                              : AppTheme.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Message Pegasus',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    HoverGlow(
                      borderRadius: BorderRadius.circular(24),
                      glowColor: AppTheme.accentGlow,
                      child: IconButton(
                        onPressed: widget.isSending ? null : _submit,
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: widget.isSending
                              ? AppTheme.textSecondary
                              : AppTheme.accent,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
