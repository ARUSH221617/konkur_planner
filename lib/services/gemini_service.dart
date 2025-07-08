import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/study_task.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';

class GeminiService {
  final String apiKey;
  final String baseUrl;

  GeminiService({required this.apiKey, this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key='});

  Future<List<StudyTask>> generateStudyPlan({
    required List<Topic> allTopics,
    required List<UserSelection> userSelections,
    required List<StudyTask> pastFeedbackTasks,
    required String userPrompt,
  }) async {
    // Construct the prompt for the Gemini AI
    String prompt = "";

    // Add syllabus data
    prompt += "Here is the Konkur syllabus data (topic, subject, estimated question count):\n";
    for (var topic in allTopics) {
      prompt += "- ${topic.name} (${topic.subject}): ${topic.questionCount} questions\n";
    }
    prompt += "\n";

    // Add user strengths
    if (userSelections.isNotEmpty) {
      prompt += "The user feels strong in the following topics (topic_id, is_strong=1):\n";
      for (var selection in userSelections) {
        final topic = allTopics.firstWhere((t) => t.id == selection.topicId);
        prompt += "- ${topic.name} (is_strong: ${selection.isStrong ? 1 : 0})\n";
      }
      prompt += "\n";
    }

    // Add past user feedback
    if (pastFeedbackTasks.isNotEmpty) {
      prompt += "Here is the user's past feedback on study sessions (topic_name, feedback):\n";
      for (var task in pastFeedbackTasks) {
        final topic = allTopics.firstWhere((t) => t.id == task.topicId);
        if (task.userFeedback != null && task.userFeedback!.isNotEmpty) {
          prompt += "- ${topic.name}: ${task.userFeedback}\n";
        }
      }
      prompt += "\n";
    }

    // Add user's specific request
    prompt += "User's request: $userPrompt\n\n";

    // Define the expected JSON output format for the study plan
    prompt += "Please generate a daily study plan in JSON format. The JSON should be an array of objects, where each object represents a study task. Each task object must have the following keys:\n";
    prompt += "- \"topic_name\": (String) The name of the topic from the syllabus.\n";
    prompt += "- \"task_date\": (String) The date of the task in YYYY-MM-DD format.\n";
    prompt += "- \"start_time\": (String) The start time in HH:MM format (24-hour).\n";
    prompt += "- \"end_time\": (String) The end time in HH:MM format (24-hour).\n";
    prompt += "- \"task_type\": (String) Either \"مرور\" (Review) or \"تست\" (Test-taking).\n";
    prompt += "\nExample JSON output:\n";
    prompt += "```json\n";
    prompt += "[\n";
    prompt += "  {\"topic_name\": \"مثلثات\", \"task_date\": \"2025-07-08\", \"start_time\": \"09:00\", \"end_time\": \"10:30\", \"task_type\": \"مرور\"},\n";
    prompt += "  {\"topic_name\": \"حد و پیوستگی\", \"task_date\": \"2025-07-08\", \"start_time\": \"11:00\", \"end_time\": \"12:00\", \"task_type\": \"تست\"}\n";
    prompt += " ]\n";
    prompt += "```\n";
    prompt += "Please provide only the JSON array, without any additional text or markdown outside the JSON block.";

    final response = await http.post(
      Uri.parse('$baseUrl$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final String? textContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

      if (textContent != null) {
        // Extract JSON from the markdown block
        final jsonString = textContent.substring(
          textContent.indexOf('```json') + 7,
          textContent.lastIndexOf('```'),
        ).trim();

        final List<dynamic> jsonList = json.decode(jsonString);
        List<StudyTask> tasks = [];

        for (var item in jsonList) {
          final topic = allTopics.firstWhere((t) => t.name == item['topic_name']);
          tasks.add(StudyTask(
            topicId: topic.id!,
            taskDate: item['task_date'],
            startTime: item['start_time'],
            endTime: item['end_time'],
            taskType: item['task_type'],
          ));
        }
        return tasks;
      } else {
        throw Exception('No text content found in Gemini response.');
      }
    } else {
      throw Exception('Failed to generate study plan: ${response.statusCode} ${response.body}');
    }
  }
}
