import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';
import '../models/study_task.dart';
import '../constants/app_constants.dart';
import '../services/notification_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'konkur_planner.db');
    return await openDatabase(
      path,
      version: 3, // Increment database version for multi-chat
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS topics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        subject TEXT,
        question_count INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_selections(
        topic_id INTEGER PRIMARY KEY,
        is_strong INTEGER,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER,
        task_date TEXT,
        start_time TEXT,
        end_time TEXT,
        task_type TEXT,
        status TEXT,
        user_feedback TEXT,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_session_id INTEGER NOT NULL,
        sender TEXT,
        message_type TEXT,
        message TEXT,
        timestamp INTEGER,
        FOREIGN KEY (chat_session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
      )
    ''');

    // Insert initial topic data
    for (var topicData in AppConstants.syllabusData) {
      await db.insert('topics', topicData, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // This block handles migration from version 1 to 2 (adding message_type to chat_history)
      // The simplest way to handle this for chat_history is to drop and recreate the table.
      // This will clear existing chat history from version 1.
      await db.execute('DROP TABLE IF EXISTS chat_history');
      await db.execute('''
        CREATE TABLE chat_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender TEXT,
          message_type TEXT,
          message TEXT,
          timestamp INTEGER
        )
      ''');
    }

    if (oldVersion < 3) {
      // This block handles migration from version 2 to 3 (adding multi-chat support)

      // 1. Create the new chat_sessions table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');

      // 2. Check if chat_history table exists and if it has the chat_session_id column
      // This is a bit tricky as we need to check for column existence.
      // A simpler approach for this specific migration is to assume if oldVersion < 3,
      // the chat_history table does NOT have chat_session_id.
      // We will rename the old table, create the new one, and migrate data.

      bool chatHistoryExists = false;
      try {
        await db.query('chat_history', limit: 0); // Check if table exists
        chatHistoryExists = true;
      } catch (e) {
        // Table does not exist
      }

      if (chatHistoryExists) {
        // Rename old chat_history table
        await db.execute('ALTER TABLE chat_history RENAME TO chat_history_old');

        // Create the new chat_history table with chat_session_id
        await db.execute('''
          CREATE TABLE chat_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_session_id INTEGER NOT NULL,
            sender TEXT,
            message_type TEXT,
            message TEXT,
            timestamp INTEGER,
            FOREIGN KEY (chat_session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
          )
        ''');

        // Insert a default chat session for existing messages
        final defaultSessionId = await db.insert('chat_sessions', {
          'title': 'Default Chat',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Copy data from old chat_history to new chat_history, assigning to default session
        await db.execute('''
          INSERT INTO chat_history (chat_session_id, sender, message_type, message, timestamp)
          SELECT ?, sender, message_type, message, timestamp FROM chat_history_old
        ''', [defaultSessionId]);

        // Drop the old chat_history table
        await db.execute('DROP TABLE IF EXISTS chat_history_old');
      }
    }
  }

  Future<int> insertChatMessage(int chatSessionId, String sender, String messageType, String message) async {
    final db = await database;
    return await db.insert('chat_history', {
      'chat_session_id': chatSessionId,
      'sender': sender,
      'message_type': messageType,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory(int chatSessionId) async {
    final db = await database;
    return await db.query(
      'chat_history',
      where: 'chat_session_id = ?',
      whereArgs: [chatSessionId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> deleteAllChatMessages(int chatSessionId) async {
    final db = await database;
    await db.delete(
      'chat_history',
      where: 'chat_session_id = ?',
      whereArgs: [chatSessionId],
    );
  }

  Future<int> insertChatSession(String title) async {
    final db = await database;
    return await db.insert('chat_sessions', {
      'title': title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getChatSessions() async {
    final db = await database;
    return await db.query('chat_sessions', orderBy: 'created_at DESC');
  }

  Future<void> deleteChatSession(int chatSessionId) async {
    final db = await database;
    await db.delete(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [chatSessionId],
    );
    // ON DELETE CASCADE will handle deleting associated chat_history messages
  }

  Future<void> updateChatSessionTitle(int sessionId, String newTitle) async {
    final db = await database;
    await db.update(
      'chat_sessions',
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> setUserSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getUserSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<List<Topic>> getTopics() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('topics');
    return List.generate(maps.length, (i) {
      return Topic.fromMap(maps[i]);
    });
  }

  Future<void> insertUserSelection(UserSelection selection) async {
    final db = await database;
    await db.insert(
      'user_selections',
      selection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserSelection>> getUserSelections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('user_selections');
    return List.generate(maps.length, (i) {
      return UserSelection.fromMap(maps[i]);
    });
  }

  Future<void> insertStudyTask(StudyTask task) async {
    final db = await database;
    final id = await db.insert('study_tasks', task.toMap());

    // Schedule notification for the newly inserted task
    final topic = (await getTopics()).firstWhere((t) => t.id == task.topicId);
    final DateTime scheduledDateTime = DateTime.parse(
        "${task.taskDate} ${task.startTime}:00"); // Assuming HH:MM format

    // Only schedule if the task is in the future
    if (scheduledDateTime.isAfter(DateTime.now())) {
      NotificationService().scheduleNotification(
        id: id, // Use the actual ID from the database
        title: "Konkur Planner: ${task.taskType} Reminder",
        body: "Topic: ${topic.name} - ${task.startTime} to ${task.endTime}",
        scheduledDate: scheduledDateTime,
        payload: id.toString(),
      );
    }
  }

  Future<List<StudyTask>> getStudyTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('study_tasks');
    return List.generate(maps.length, (i) {
      return StudyTask.fromMap(maps[i]);
    });
  }

  Future<void> updateStudyTaskStatus(int taskId, String status) async {
    final db = await database;
    await db.update(
      'study_tasks',
      {'status': status},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> updateStudyTaskFeedback(int taskId, String feedback) async {
    final db = await database;
    await db.update(
      'study_tasks',
      {'user_feedback': feedback},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<StudyTask>> getStudyTasksByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_tasks',
      where: 'task_date = ?',
      whereArgs: [date],
      orderBy: 'start_time ASC',
    );
    return List.generate(maps.length, (i) {
      return StudyTask.fromMap(maps[i]);
    });
  }

  Future<List<Map<String, dynamic>>> getTopicsWithUserSelection() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        t.id,
        t.name,
        t.subject,
        t.question_count,
        COALESCE(us.is_strong, 0) AS is_strong
      FROM
        topics AS t
      LEFT JOIN
        user_selections AS us
      ON
        t.id = us.topic_id
      ORDER BY
        t.subject, t.name
    ''');
    return result;
  }

  Future<void> deleteAllTasks() async {
    final db = await database;
    await db.delete('study_tasks');
    NotificationService().cancelAllNotifications(); // Cancel all notifications when tasks are deleted
  }

  Future<List<Map<String, dynamic>>> getStudyTasksWithTopicDetails() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        st.id,
        st.task_date,
        st.start_time,
        st.end_time,
        st.task_type,
        st.status,
        st.user_feedback,
        t.name AS topic_name,
        t.subject AS topic_subject
      FROM
        study_tasks AS st
      JOIN
        topics AS t
      ON
        st.topic_id = t.id
      ORDER BY
        st.task_date, st.start_time
    ''');
    return result;
  }
}
