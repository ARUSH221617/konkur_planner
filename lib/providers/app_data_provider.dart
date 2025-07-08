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

  final DatabaseHelper _dbHelper = DatabaseHelper();

  AppDataProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    await _dbHelper.database; // Ensure database is initialized and topics are inserted
    _topics = await _dbHelper.getTopics();
    _userSelections = await _dbHelper.getUserSelections();
    _studyTasks = await _dbHelper.getStudyTasks();
    notifyListeners();
  }

  Future<void> refreshData() async {
    _topics = await _dbHelper.getTopics();
    _userSelections = await _dbHelper.getUserSelections();
    _studyTasks = await _dbHelper.getStudyTasks();
    notifyListeners();
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

  Future<List<Map<String, dynamic>>> getTopicsWithUserSelection() async {
    return await _dbHelper.getTopicsWithUserSelection();
  }

  Future<List<Map<String, dynamic>>> getStudyTasksWithTopicDetails() async {
    return await _dbHelper.getStudyTasksWithTopicDetails();
  }
}
