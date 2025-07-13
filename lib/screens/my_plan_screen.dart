import 'package:flutter/material.dart';
import 'package:konkur_planner/screens/timer_screen.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/study_task.dart';
import '../providers/app_data_provider.dart';
import '../services/notification_service.dart';

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _showAllTasks = false;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  void _startTimer(StudyTask task) async {
    // Mark task as in_progress
    Provider.of<AppDataProvider>(
      context,
      listen: false,
    ).updateTaskStatus(task.id!, 'in_progress');
    _notificationService.cancelNotification(task.hashCode); // Cancel notification when starting

    // Navigate to TimerScreen and wait for it to pop
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => TimerScreen(task: task)));

    if (result == 'paused') {
      Provider.of<AppDataProvider>(
        context,
        listen: false,
      ).updateTaskStatus(task.id!, 'paused');
      _notificationService.cancelNotification(task.hashCode); // Cancel notification when paused
    } else {
      // After returning from TimerScreen, show feedback dialog
      _showFeedbackDialog(task);
    }
  }

  void _showFeedbackDialog(StudyTask task) {
    TextEditingController feedbackController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Feedback for ${task.taskType}'),
          content: TextField(
            controller: feedbackController,
            decoration: const InputDecoration(
              labelText: 'Your feedback (e.g., what you learned, difficulties)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Submit'),
              onPressed: () async {
                await Provider.of<AppDataProvider>(
                  context,
                  listen: false,
                ).updateTaskFeedback(task.id!, feedbackController.text);
                await Provider.of<AppDataProvider>(
                  context,
                  listen: false,
                ).updateTaskStatus(task.id!, 'completed');
                _notificationService.cancelNotification(task.hashCode); // Cancel notification on completion
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه من'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _showAllTasks ? Icons.calendar_today : Icons.calendar_view_month,
            ),
            tooltip: _showAllTasks ? "Show Today's Tasks" : "Show All Tasks",
            onPressed: () {
              setState(() {
                _showAllTasks = !_showAllTasks;
              });
            },
          ),
        ],
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, appData, child) {
          final List<StudyTask> tasksToShow;
          if (_showAllTasks) {
            tasksToShow = appData.studyTasks;
          } else {
            final now = DateTime.now();
            tasksToShow = appData.studyTasks.where((task) {
              final taskDate = DateTime.parse(task.taskDate);
              return taskDate.year == now.year &&
                  taskDate.month == now.month &&
                  taskDate.day == now.day;
            }).toList();
          }

          if (tasksToShow.isEmpty) {
            return Center(
              child: Text(
                _showAllTasks
                    ? 'No study plan generated yet. Go to AI Agent to create one!'
                    : 'No tasks for today. You can view all tasks or create a new plan.',
              ),
            );
          }

          // Group tasks by date
          final Map<String, List<Map<String, dynamic>>> groupedTasks = {};
          for (var taskData in tasksToShow) {
            final date = taskData.taskDate;
            if (!groupedTasks.containsKey(date)) {
              groupedTasks[date] = [];
            }
            groupedTasks[date]!.add({
              'id': taskData.id,
              'topic_id': taskData.topicId,
              'task_date': taskData.taskDate,
              'start_time': taskData.startTime,
              'end_time': taskData.endTime,
              'task_type': taskData.taskType,
              'status': taskData.status,
              'user_feedback': taskData.userFeedback,
              // Add topic details from appData.topics
              'topic_name': appData.topics
                  .firstWhere((t) => t.id == taskData.topicId)
                  .name,
              'topic_subject': appData.topics
                  .firstWhere((t) => t.id == taskData.topicId)
                  .subject,
            });
          }

          final sortedDates = groupedTasks.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final tasksForDate = groupedTasks[date]!;
              formattedJalaliDate(date) {
                final jalali = Jalali.fromDateTime(
                  DateTime.parse(date),
                ).formatter;
                return '${jalali.yyyy}/${jalali.mm}/${jalali.dd}';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      formattedJalaliDate(date),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  ...tasksForDate.map((taskData) {
                    final task = StudyTask.fromMap(taskData);
                    final topicName = taskData['topic_name'];
                    final topicSubject = taskData['topic_subject'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      elevation: 1,
                      child: ListTile(
                        title: Text('$topicName - $topicSubject'),
                        subtitle: Text(
                          '${task.startTime} - ${task.endTime} (${task.taskType})',
                        ),
                        trailing: task.status == 'pending'
                            ? IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: 'Start Task',
                                onPressed: () => _startTimer(task),
                              )
                            : task.status == 'paused'
                            ? IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: 'Resume Task',
                                onPressed: () => _startTimer(task),
                              )
                            : Text(task.status),
                        tileColor: task.status == 'completed'
                            ? Colors.green[50]
                            : task.status == 'paused'
                            ? Colors.orange[50]
                            : null,
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
