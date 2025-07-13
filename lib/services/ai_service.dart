import 'dart:async';
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
  final GenerativeModel _titleGenerationModel;

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
        parameters: {},
      ),
    ]),
  ];

  /// The constructor now initializes the models using the FirebaseAI service.
  AIService()
    : _chatModel = FirebaseAI.googleAI(auth: FirebaseAuth.instance)
          .generativeModel(
            model: 'gemini-1.5-flash',
            tools: _tools,
            systemInstruction: Content.text(
              'You are a helpful AI study assistant for Iranian Konkur students, specializing in the Math & Physics track. Your primary goal is to help users create personalized study plans, provide academic guidance, and answer questions related to Konkur topics. Always be polite, encouraging, and provide accurate information based on the official Iranian Konkur syllabus. When generating study plans, prioritize topics based on their official question count (importance) and the user\'s self-assessed strengths/weaknesses. Respond in Persian when appropriate for the user\'s query, otherwise use English. When generating chat titles, be concise and descriptive, outputting only the title text.',
            ),
          ),
      _jsonGenerationModel = FirebaseAI.googleAI(auth: FirebaseAuth.instance)
          .generativeModel(
            model: 'gemini-1.5-flash',
            // Enable JSON mode for reliable structured output.
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
            systemInstruction: Content.text(
              'You are a helpful AI study assistant for Iranian Konkur students, specializing in the Math & Physics track. Your primary goal is to help users create personalized study plans, provide academic guidance, and answer questions related to Konkur topics. Always be polite, encouraging, and provide accurate information based on the official Iranian Konkur syllabus. When generating study plans, prioritize topics based on their official question count (importance) and the user\'s self-assessed strengths/weaknesses. Respond in Persian when appropriate for the user\'s query, otherwise use English. When generating chat titles, be concise and descriptive, outputting only the title text.',
            ),
          ),
      _titleGenerationModel = FirebaseAI.googleAI(auth: FirebaseAuth.instance)
          .generativeModel(
            model: 'gemini-1.5-flash',
            systemInstruction: Content.text(
              'You are a helpful AI assistant. Your sole purpose is to generate a concise and descriptive title for a given conversation. Respond with only the title text, no other formatting or explanation.',
            ),
          );

  Future<ChatSession> startChat({List<Content>? history}) async {
    debugPrint("[AIService] Starting new chat session with Firebase AI.");
    return _chatModel.startChat(history: history);
  }

  Future<String> generateChatTitle(List<Content> chatHistory) async {
    debugPrint("[AIService] Generating chat title...");
    try {
      final prompt = Content.text(
        'Given the following chat messages, generate a concise and descriptive title for this conversation. The title should be in the same language as the conversation. Respond with only the title text, no other formatting or explanation. The title must not be "New Chat".',
      );
      final response = await _titleGenerationModel.generateContent([
        prompt,
        ...chatHistory,
      ]);

      final title = response.text?.trim();
      if (title != null && title.isNotEmpty && title != 'New Chat') {
        debugPrint("[AIService] Generated title: '$title'");
        return title;
      } else {
        debugPrint(
          "[AIService] Generated a null, empty, or default title. Using fallback.",
        );
        // Fallback for empty or default title
        final fallbackTitle = (chatHistory.first.parts.first as TextPart).text;
        return fallbackTitle.substring(
          0,
          fallbackTitle.length > 30 ? 30 : fallbackTitle.length,
        );
      }
    } catch (e) {
      debugPrint("[AIService] Error generating chat title: $e");
      // Fallback on error
      final fallbackTitle = (chatHistory.first.parts.first as TextPart).text;
      return fallbackTitle.substring(
        0,
        fallbackTitle.length > 30 ? 30 : fallbackTitle.length,
      );
    }
  }

  Stream<String> sendMessage({
    required ChatSession chatSession,
    required String prompt,
    required void Function(String name, Map<String, dynamic> args)
    onFunctionCall,
    required void Function(Map<String, Object?> result) onFunctionResult,
    required Future<Map<String, Object?>> Function({
      required int studyDays,
      int? studyHoursPerDay,
      List<String>? focusTopics,
    })
    onGeneratePlan,
    required Map<String, Object?> Function() onGetWeakTopics,
  }) {
    final controller = StreamController<String>();

    Future<void> process() async {
      try {
        debugPrint("[AIService] Sending message to AI: '$prompt'");
        final stream = chatSession.sendMessageStream(Content.text(prompt));
        FunctionCall? functionCall;

        // Listen to the stream for text chunks and potential function calls
        await for (final response in stream) {
          if (response.functionCalls.isNotEmpty) {
            // Assuming the first function call is the one to execute
            functionCall = response.functionCalls.first;
            break; // Exit the loop to handle the function call
          }
          if (response.text != null) {
            controller.add(response.text!);
          }
        }

        // If a function call was received, handle it
        if (functionCall != null) {
          debugPrint(
            "[AIService] AI requested function call: '${functionCall.name}' with args: ${functionCall.args}",
          );
          onFunctionCall(functionCall.name, functionCall.args);

          final functionResult = await _handleFunctionCall(
            functionCall,
            onGeneratePlan: onGeneratePlan,
            onGetWeakTopics: onGetWeakTopics,
          );

          debugPrint("[AIService] Function call result: $functionResult");
          onFunctionResult(functionResult);

          // Send the function response back and stream the final answer
          final responseStreamAfterFunction = chatSession.sendMessageStream(
            Content.functionResponse(functionCall.name, functionResult),
          );

          await for (final response in responseStreamAfterFunction) {
            if (response.text != null) {
              controller.add(response.text!);
            }
          }
        }
      } catch (e) {
        debugPrint("[AIService] ERROR sending message: $e");
        controller.addError(e);
      } finally {
        // Close the stream controller when all operations are complete
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    process();
    return controller.stream;
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
        final studyTask = StudyTask(
          topicId: topic.id!,
          taskDate: item['task_date'],
          startTime: item['start_time'],
          endTime: item['end_time'],
          taskType: item['task_type'],
        );
        tasks.add(studyTask);
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
    buffer.writeln(
      '- Start Date: ${DateTime.now().toIso8601String().split('T').first} (today\'s date).',
    );
    if (focusTopics.isNotEmpty) {
      buffer.writeln('- Prioritize these topics: ${focusTopics.join(', ')}.');
    }
    buffer.writeln(
      '- Available Topics (choose only from this list for "topic_name"): ${allTopics.map((e) => e.name).join(', ')}.',
    );
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
