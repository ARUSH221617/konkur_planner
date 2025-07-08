class StudyTask {
  final int? id;
  final int topicId;
  final String taskDate;
  final String startTime;
  final String endTime;
  final String taskType;
  String status;
  String? userFeedback;

  StudyTask({
    this.id,
    required this.topicId,
    required this.taskDate,
    required this.startTime,
    required this.endTime,
    required this.taskType,
    this.status = 'pending',
    this.userFeedback,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic_id': topicId,
      'task_date': taskDate,
      'start_time': startTime,
      'end_time': endTime,
      'task_type': taskType,
      'status': status,
      'user_feedback': userFeedback,
    };
  }

  factory StudyTask.fromMap(Map<String, dynamic> map) {
    return StudyTask(
      id: map['id'],
      topicId: map['topic_id'],
      taskDate: map['task_date'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      taskType: map['task_type'],
      status: map['status'],
      userFeedback: map['user_feedback'],
    );
  }
}
