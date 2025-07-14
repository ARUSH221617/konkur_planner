import 'dart:async';
import 'package:flutter/material.dart';
import '../models/study_task.dart';

class TimerScreen extends StatefulWidget {
  final StudyTask task;

  const TimerScreen({super.key, required this.task});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _timer;
  late int _remainingTime; // in seconds
  bool _isPaused = false;

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
            Navigator.of(context).pop();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_remainingTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingTime % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('وظیفه: ${widget.task.taskType}'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formattedTime,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  iconSize: 50,
                  onPressed: _togglePause,
                ),
                const SizedBox(width: 40),
                ElevatedButton(
                  child: const Text('فعلاً متوقف کن'),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.of(context).pop('paused');
                  },
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  child: const Text('پایان وظیفه'),
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.of(context).pop('completed');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
