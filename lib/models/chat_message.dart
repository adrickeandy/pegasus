enum MessageRole { user, model, error }

/// A file attached to a single message. Only kept in memory for the
/// duration of the request that sends it — see storage_service.dart for
/// why the raw bytes aren't persisted to disk long-term.
class Attachment {
  final String name;
  final String mimeType;
  final String base64Data;

  Attachment({
    required this.name,
    required this.mimeType,
    required this.base64Data,
  });
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final String? attachmentName;
  final String? attachmentMimeType;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.attachmentName,
    this.attachmentMimeType,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isError => role == MessageRole.error;
  bool get hasAttachment => attachmentName != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'text': text,
        'role': role.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'attachment_name': attachmentName,
        'attachment_mime': attachmentMimeType,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        text: map['text'] as String,
        role: MessageRole.values.byName(map['role'] as String),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        attachmentName: map['attachment_name'] as String?,
        attachmentMimeType: map['attachment_mime'] as String?,
      );

  ChatMessage copyWith({String? text}) => ChatMessage(
        id: id,
        conversationId: conversationId,
        text: text ?? this.text,
        role: role,
        timestamp: timestamp,
        attachmentName: attachmentName,
        attachmentMimeType: attachmentMimeType,
      );
}
