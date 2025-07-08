
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';
import '../models/study_task.dart';
import '../services/notification_service.dart';

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  void _startTimer(StudyTask task) {
    // TODO: Implement actual timer logic and UI
    // For now, just mark as in_progress and show a dialog
    Provider.of<AppDataProvider>(context, listen: false).updateTaskStatus(task.id!, 'in_progress');
    _showTimerDialog(task);
  }

  void _showTimerDialog(StudyTask task) {
    TextEditingController feedbackController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Task: ${task.taskType} ${task.topicId}'), // Will show topic name later
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Time for your study session!'),
                SizedBox(height: 20),
                TextField(
                  controller: feedbackController,
                  decoration: InputDecoration(
                    labelText: 'Your feedback (e.g., what you learned, difficulties)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Mark as Completed'),
              onPressed: () async {
                await Provider.of<AppDataProvider>(context, listen: false).updateTaskFeedback(task.id!, feedbackController.text);
                await Provider.of<AppDataProvider>(context, listen: false).updateTaskStatus(task.id!, 'completed');
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
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, appData, child) {
          if (appData.studyTasks.isEmpty) {
            return const Center(child: Text('No study plan generated yet. Go to AI Agent to create one!'));
          }

          // Group tasks by date
          final Map<String, List<Map<String, dynamic>>> groupedTasks = {};
          for (var taskData in appData.studyTasks) {
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
              'topic_name': appData.topics.firstWhere((t) => t.id == taskData.topicId).name,
              'topic_subject': appData.topics.firstWhere((t) => t.id == taskData.topicId).subject,
            });
          }

          final sortedDates = groupedTasks.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final tasksForDate = groupedTasks[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(DateTime.parse(date)),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                        subtitle: Text('${task.startTime} - ${task.endTime} (${task.taskType})'),
                        trailing: task.status == 'pending'
                            ? IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _startTimer(task),
                              )
                            : Text(task.status),
                        tileColor: task.status == 'completed' ? Colors.green[50] : null,
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
