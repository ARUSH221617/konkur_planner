import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_task.dart';
import '../providers/app_data_provider.dart';

class TimerDialog extends StatefulWidget {
  final StudyTask task;

  const TimerDialog({super.key, required this.task});

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  Timer? _timer;
  late int _remainingTime; // in seconds
  bool _isPaused = false;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _remainingTime = _calculateDuration();
    _startTimer();
  }

  int _calculateDuration() {
    final startTime = TimeOfDay(
      hour: int.parse(widget.task.startTime.split(':')[0]),
      minute: int.parse(widget.task.startTime.split(':')[1]),
    );
    final endTime = TimeOfDay(
      hour: int.parse(widget.task.endTime.split(':')[0]),
      minute: int.parse(widget.task.endTime.split(':')[1]),
    );
    final now = DateTime.now();
    final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
    final endDateTime = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
    return endDateTime.difference(startDateTime).inSeconds;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_remainingTime > 0) {
            _remainingTime--;
          } else {
            _timer?.cancel();
            _markAsCompleted();
          }
        });
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _markAsCompleted() async {
    await Provider.of<AppDataProvider>(context, listen: false)
        .updateTaskFeedback(widget.task.id!, _feedbackController.text);
    await Provider.of<AppDataProvider>(context, listen: false)
        .updateTaskStatus(widget.task.id!, 'completed');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_remainingTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingTime % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('وظیفه: ${widget.task.taskType}'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              _formattedTime,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'بازخورد شما (مثلاً چه چیزی یاد گرفتید، مشکلات)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
          onPressed: _togglePause,
        ),
        TextButton(
          child: const Text('علامت‌گذاری به عنوان تکمیل شده'),
          onPressed: () {
            _timer?.cancel();
            _markAsCompleted();
          },
        ),
      ],
    );
  }
}
