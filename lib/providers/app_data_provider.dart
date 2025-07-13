import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';
import '../models/study_task.dart';

class AppDataProvider with ChangeNotifier {
  List<Topic> _topics = [];
  List<UserSelection> _userSelections = [];
  List<StudyTask> _studyTasks = [];

  List<Topic> get topics => _topics;
  List<UserSelection> get userSelections => _userSelections;
  List<StudyTask> get studyTasks => _studyTasks;
  List<Map<String, dynamic>> _chatHistory = [];
  List<Map<String, dynamic>> get chatHistory => _chatHistory;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  AppDataProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    await _dbHelper.database; // Ensure database is initialized and topics are inserted
    _topics = await _dbHelper.getTopics();
    _userSelections = await _dbHelper.getUserSelections();
    _studyTasks = await _dbHelper.getStudyTasks();
    _chatHistory = await _dbHelper.getChatHistory();
    notifyListeners();
  }

  Future<void> refreshData() async {
    _topics = await _dbHelper.getTopics();
    _userSelections = await _dbHelper.getUserSelections();
    _studyTasks = await _dbHelper.getStudyTasks();
    _chatHistory = await _dbHelper.getChatHistory();
    notifyListeners();
  }

  Future<void> addChatMessage(String sender, String messageType, String message) async {
    await _dbHelper.insertChatMessage(sender, messageType, message);
    await refreshData();
  }

  Future<void> deleteAllChatMessages() async {
    await _dbHelper.deleteAllChatMessages();
    await refreshData();
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
    await _dbHelper.setUserSetting('userBirthdate', birthdate.toIso8601String());
    notifyListeners();
  }

  Future<DateTime?> getUserBirthdate() async {
    final birthdateString = await _dbHelper.getUserSetting('userBirthdate');
    if (birthdateString != null) {
      return DateTime.tryParse(birthdateString);
    }
    return null;
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
