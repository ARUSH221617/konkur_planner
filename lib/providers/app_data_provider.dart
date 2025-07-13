import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/chat_session.dart'; // Import ChatSession model
import '../models/study_task.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';

class AppDataProvider with ChangeNotifier {
  List<Topic> _topics = [];
  List<UserSelection> _userSelections = [];
  List<StudyTask> _studyTasks = [];
  List<ChatSession> _chatSessions = []; // New: List of chat sessions
  int? _currentChatSessionId; // New: Currently active chat session ID

  List<Topic> get topics => _topics;
  List<UserSelection> get userSelections => _userSelections;
  List<StudyTask> get studyTasks => _studyTasks;
  List<Map<String, dynamic>> _chatHistory = [];
  List<Map<String, dynamic>> get chatHistory => _chatHistory;
  List<ChatSession> get chatSessions => _chatSessions; // New getter
  int? get currentChatSessionId => _currentChatSessionId; // New getter

  final DatabaseHelper _dbHelper = DatabaseHelper();

  AppDataProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    await _dbHelper
        .database; // Ensure database is initialized and topics are inserted
    _topics = await _dbHelper.getTopics();
    _userSelections = await _dbHelper.getUserSelections();
    _studyTasks = await _dbHelper.getStudyTasks();

    _chatSessions = await _dbHelper.getChatSessions().then(
      (maps) => maps.map((e) => ChatSession.fromMap(e)).toList(),
    );

    if (_chatSessions.isEmpty) {
      // Create a default chat session if none exist
      final newSessionId = await _dbHelper.insertChatSession('New Chat');
      _currentChatSessionId = newSessionId;
      _chatSessions = await _dbHelper.getChatSessions().then(
        (maps) => maps.map((e) => ChatSession.fromMap(e)).toList(),
      );
    } else {
      // Set the current chat session to the most recent one
      _currentChatSessionId = _chatSessions.first.id;
    }

    if (_currentChatSessionId != null) {
      _chatHistory = await _dbHelper.getChatHistory(_currentChatSessionId!);
    } else {
      _chatHistory = [];
    }
    notifyListeners();
  }

  Future<void> refreshData() async {
    _topics = await _dbHelper.getTopics();
    _userSelections = await _dbHelper.getUserSelections();
    _studyTasks = await _dbHelper.getStudyTasks();

    _chatSessions = await _dbHelper.getChatSessions().then(
      (maps) => maps.map((e) => ChatSession.fromMap(e)).toList(),
    );

    if (_chatSessions.isNotEmpty && _currentChatSessionId == null) {
      _currentChatSessionId = _chatSessions.first.id;
    }

    if (_currentChatSessionId != null) {
      _chatHistory = await _dbHelper.getChatHistory(_currentChatSessionId!);
    } else {
      _chatHistory = [];
    }
    notifyListeners();
  }

  Future<void> addChatMessage(
    String sender,
    String messageType,
    String message,
  ) async {
    if (_currentChatSessionId == null) {
      // This should ideally not happen if _loadData is called correctly,
      // but as a fallback, create a default session.
      await createNewChatSession('Default Chat');
    }
    await _dbHelper.insertChatMessage(
      _currentChatSessionId!,
      sender,
      messageType,
      message,
    );
    await refreshData();
  }

  Future<void> deleteAllChatMessages() async {
    if (_currentChatSessionId != null) {
      await _dbHelper.deleteAllChatMessages(
        _currentChatSessionId!,
      ); // Delete messages for current session
      await refreshData();
    }
  }

  Future<void> updateUserSelection(UserSelection selection) async {
    await _dbHelper.insertUserSelection(selection);
    await refreshData();
  }

  Future<void> addStudyTasks(List<StudyTask> tasks) async {
    for (var task in tasks) {
      await _dbHelper.insertStudyTask(task);
    }
    await refreshData();
  }

  Future<void> updateTaskStatus(int taskId, String status) async {
    await _dbHelper.updateStudyTaskStatus(taskId, status);
    await refreshData();
  }

  Future<void> updateTaskFeedback(int taskId, String feedback) async {
    await _dbHelper.updateStudyTaskFeedback(taskId, feedback);
    await refreshData();
  }

  Future<void> setUserName(String name) async {
    await _dbHelper.setUserSetting('userName', name);
    notifyListeners();
  }

  Future<String> getUserName() async {
    return await _dbHelper.getUserSetting('userName') ?? 'Konkur Planner User';
  }

  Future<void> setUserEmail(String email) async {
    await _dbHelper.setUserSetting('userEmail', email);
    notifyListeners();
  }

  Future<String?> getUserEmail() async {
    return await _dbHelper.getUserSetting('userEmail');
  }

  Future<void> setUserBirthdate(DateTime birthdate) async {
    await _dbHelper.setUserSetting(
      'userBirthdate',
      birthdate.toIso8601String(),
    );
    notifyListeners();
  }

  Future<DateTime?> getUserBirthdate() async {
    final birthdateString = await _dbHelper.getUserSetting('userBirthdate');
    if (birthdateString != null) {
      return DateTime.tryParse(birthdateString);
    }
    return null;
  }

  Future<void> createNewChatSession(String title) async {
    final newSessionId = await _dbHelper.insertChatSession(title);
    _currentChatSessionId = newSessionId;
    await refreshData();
  }

  Future<void> switchChatSession(int sessionId) async {
    _currentChatSessionId = sessionId;
    await refreshData();
  }

  Future<void> deleteChatSession(int sessionId) async {
    await _dbHelper.deleteChatSession(sessionId);
    // If the deleted session was the current one, switch to the most recent remaining session
    if (_currentChatSessionId == sessionId) {
      _chatSessions = await _dbHelper.getChatSessions().then(
        (maps) => maps.map((e) => ChatSession.fromMap(e)).toList(),
      );
      _currentChatSessionId = _chatSessions.isNotEmpty
          ? _chatSessions.first.id
          : null;
    }
    await refreshData();
  }

  Future<void> updateChatSessionTitle(int sessionId, String newTitle) async {
    await _dbHelper.updateChatSessionTitle(sessionId, newTitle);
    final sessionIndex = _chatSessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (sessionIndex != -1) {
      final oldSession = _chatSessions[sessionIndex];
      _chatSessions[sessionIndex] = ChatSession(
        id: oldSession.id,
        title: newTitle,
        createdAt: oldSession.createdAt,
      );
    }
    notifyListeners();
  }

  Future<void> deleteAllTasks() async {
    await _dbHelper.deleteAllTasks();
    await refreshData();
  }

  Future<List<Map<String, dynamic>>> getTopicsWithUserSelection() async {
    return await _dbHelper.getTopicsWithUserSelection();
  }

  Future<List<Map<String, dynamic>>> getStudyTasksWithTopicDetails() async {
    return await _dbHelper.getStudyTasksWithTopicDetails();
  }
}
