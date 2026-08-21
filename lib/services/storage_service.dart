import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Local persistence for conversations and messages using SQLite.
///
/// Design note: attachment *bytes* are never written to disk here — only
/// the file's name and mime type are stored, purely for display in the
/// message history. Persisting raw base64 file data would bloat the
/// database fast (a single image can be 1-2MB+ as base64 text). If you
/// want attachments to be re-viewable after an app restart, the next
/// step would be saving the file to app storage via path_provider and
/// storing just its local path here instead of the raw bytes.
class StorageService {
  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pegasus.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            attachment_name TEXT,
            attachment_mime TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conv ON messages(conversation_id)',
        );
      },
    );
  }

  // ---- Conversations ----

  Future<void> saveConversation(Conversation c) async {
    final db = await _database;
    await db.insert(
      'conversations',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Conversation>> getConversations() async {
    final db = await _database;
    final rows = await db.query('conversations', orderBy: 'updated_at DESC');
    return rows.map((r) => Conversation.fromMap(r)).toList();
  }

  Future<void> deleteConversation(String id) async {
    final db = await _database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Messages ----

  Future<void> saveMessage(ChatMessage m) async {
    final db = await _database;
    await db.insert(
      'messages',
      m.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => ChatMessage.fromMap(r)).toList();
  }
}
