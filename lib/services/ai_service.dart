import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/study_task.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';

/// A service class to handle all interactions with the Gemini AI model via Firebase,
/// including conversational chat and function calling.
class AIService {
  final GenerativeModel _chatModel;
  final GenerativeModel _jsonGenerationModel;

  // Tool definition remains the same as it's a standard structure.
  static final List<Tool> _tools = [
    Tool.functionDeclarations([
      FunctionDeclaration(
        'generateStudyPlan',
        'Generates a detailed, day-by-day study plan based on the user\'s request and profile.',
        parameters: {
          'studyDays': Schema(
            SchemaType.integer,
            description:
                'The total number of days the plan should cover. For example, if the user asks for a "weekly plan", this should be 7.',
          ),
          'studyHoursPerDay': Schema(
            SchemaType.integer,
            description:
                'The approximate number of hours the user can study each day. Defaults to 4 if not specified.',
          ),
          'focusTopics': Schema(
            SchemaType.array,
            items: Schema(SchemaType.string),
            description:
                'A list of specific subjects or topics the user wants to prioritize.',
          ),
        },
        optionalParameters: ['studyHoursPerDay', 'focusTopics'],
      ),
      FunctionDeclaration(
        'getWeakestTopics',
        "Identifies and returns a list of the user's weakest topics based on their self-assessment.",
        parameters: {}
      ),
    ]),
  ];

  /// The constructor now initializes the models using the FirebaseAI service.
  AIService()
    : _chatModel = FirebaseAI.googleAI(
        auth: FirebaseAuth.instance,
      ).generativeModel(model: 'gemini-2.5-flash', tools: _tools),
      _jsonGenerationModel = FirebaseAI.googleAI(auth: FirebaseAuth.instance)
          .generativeModel(
            model: 'gemini-2.5-flash',
            // Enable JSON mode for reliable structured output.
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
          );

  Future<ChatSession> startChat() async {
    debugPrint("[AIService] Starting new chat session with Firebase AI.");
    return _chatModel.startChat();
  }

  Future<String> sendMessage({
    required ChatSession chatSession,
    required String prompt,
    required Future<Map<String, Object?>> Function({
      required int studyDays,
      int? studyHoursPerDay,
      List<String>? focusTopics,
    })
    onGeneratePlan,
    required Map<String, Object?> Function() onGetWeakTopics,
  }) async {
    debugPrint("[AIService] Sending message to AI: '$prompt'");
    try {
      // The sendMessage API is very similar.
      final response = await chatSession.sendMessage(Content.text(prompt));
      final call = response.functionCalls.firstOrNull;

      if (call != null) {
        debugPrint(
          "[AIService] AI requested to call function: '${call.name}' with args: ${call.args}",
        );
        final functionResult = await _handleFunctionCall(
          call,
          onGeneratePlan: onGeneratePlan,
          onGetWeakTopics: onGetWeakTopics,
        );

        debugPrint("[AIService] Function call result: $functionResult");

        final responseAfterFunction = await chatSession.sendMessage(
          Content.functionResponse(call.name, functionResult),
        );
        debugPrint(
          "[AIService] Received final AI response after function call: '${responseAfterFunction.text}'",
        );
        return responseAfterFunction.text ?? "I've processed your request.";
      }

      debugPrint(
        "[AIService] Received standard AI response: '${response.text}'",
      );
      return response.text ?? "Sorry, I couldn't process that.";
    } catch (e) {
      debugPrint("[AIService] ERROR sending message: $e");
      rethrow;
    }
  }

  Future<Map<String, Object?>> _handleFunctionCall(
    FunctionCall call, {
    required Future<Map<String, Object?>> Function({
      required int studyDays,
      int? studyHoursPerDay,
      List<String>? focusTopics,
    })
    onGeneratePlan,
    required Map<String, Object?> Function() onGetWeakTopics,
  }) {
    switch (call.name) {
      case 'generateStudyPlan':
        return onGeneratePlan(
          studyDays: call.args['studyDays'] as int,
          studyHoursPerDay: call.args['studyHoursPerDay'] as int?,
          focusTopics: (call.args['focusTopics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
        );
      case 'getWeakestTopics':
        return Future.value(onGetWeakTopics());
      default:
        throw Exception('Unknown function call: ${call.name}');
    }
  }

  Future<List<StudyTask>> getStudyPlanJson({
    required List<Topic> allTopics,
    required List<UserSelection> userSelections,
    required int studyDays,
    int? studyHoursPerDay,
    List<String>? focusTopics,
  }) async {
    // The prompt is now much simpler thanks to JSON mode.
    final prompt = _buildJsonSchedulePrompt(
      allTopics,
      userSelections,
      studyDays,
      studyHoursPerDay ?? 4,
      focusTopics ?? [],
    );

    final content = [Content.text(prompt)];
    final response = await _jsonGenerationModel.generateContent(content);

    if (response.text == null) {
      throw Exception('The AI returned an empty plan. Please try again.');
    }

    try {
      // No need to extract JSON from markdown anymore.
      final List<dynamic> jsonList = json.decode(response.text!);

      List<StudyTask> tasks = [];
      for (var item in jsonList) {
        final topic = allTopics.firstWhere(
          (t) => t.name == item['topic_name'],
          orElse: () => throw Exception(
            'The AI mentioned a topic not found in the syllabus: "${item['topic_name']}"',
          ),
        );
        tasks.add(
          StudyTask(
            topicId: topic.id!,
            taskDate: item['task_date'],
            startTime: item['start_time'],
            endTime: item['end_time'],
            taskType: item['task_type'],
          ),
        );
      }
      return tasks;
    } on FormatException catch (e) {
      debugPrint("AI response that caused format error: ${response.text}");
      throw FormatException(
        "The AI's response was not in the expected format. ${e.message}",
      );
    }
  }

  String _buildJsonSchedulePrompt(
    List<Topic> allTopics,
    List<UserSelection> userSelections,
    int studyDays,
    int studyHoursPerDay,
    List<String> focusTopics,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Generate a study plan based on the following constraints and user profile. The output must be a valid JSON array of objects.',
    );
    buffer.writeln('## Constraints:');
    buffer.writeln('- Plan Duration: $studyDays days.');
    buffer.writeln('- Daily Study: $studyHoursPerDay hours.');
    if (focusTopics.isNotEmpty) {
      buffer.writeln('- Prioritize these topics: ${focusTopics.join(', ')}.');
    }
    buffer.writeln('## User Profile:');
    for (final topic in allTopics) {
      final selection = userSelections.firstWhere(
        (s) => s.topicId == topic.id,
        orElse: () => UserSelection(topicId: topic.id!, isStrong: false),
      );
      buffer.writeln(
        '- Topic: ${topic.name}, Importance: ${topic.questionCount}, User feels: ${selection.isStrong ? "Strong" : "Weak"}',
      );
    }
    buffer.writeln('## Required JSON Schema:');
    buffer.writeln(
      '[{"topic_name": string, "task_date": "YYYY-MM-DD", "start_time": "HH:MM", "end_time": "HH:MM", "task_type": "مرور" | "تست"}]',
    );
    return buffer.toString();
  }
}
