class UserSelection {
  final int topicId;
  final bool isStrong;

  UserSelection({
    required this.topicId,
    required this.isStrong,
  });

  Map<String, dynamic> toMap() {
    return {
      'topic_id': topicId,
      'is_strong': isStrong ? 1 : 0,
    };
  }

  factory UserSelection.fromMap(Map<String, dynamic> map) {
    return UserSelection(
      topicId: map['topic_id'],
      isStrong: map['is_strong'] == 1,
    );
  }
}
