import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';
import '../models/study_task.dart';
import '../constants/app_constants.dart';

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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE topics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        subject TEXT,
        question_count INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE user_selections(
        topic_id INTEGER PRIMARY KEY,
        is_strong INTEGER,
        FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_tasks(
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

    // Insert initial topic data
    for (var topicData in AppConstants.syllabusData) {
      await db.insert('topics', topicData);
    }
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
    await db.insert('study_tasks', task.toMap());
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
