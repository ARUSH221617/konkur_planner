class Topic {
  final int? id;
  final String name;
  final String subject;
  final int questionCount;

  Topic({
    this.id,
    required this.name,
    required this.subject,
    required this.questionCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'question_count': questionCount,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'],
      name: map['name'],
      subject: map['subject'],
      questionCount: map['question_count'],
    );
  }
}
