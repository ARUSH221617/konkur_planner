import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../services/gemini_service.dart';
import '../models/study_task.dart';
import '../models/topic.dart';
import '../models/user_selection.dart';

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({super.key});

  @override
  State<AIAgentScreen> createState() => _AIAgentScreenState();
}

class _AIAgentScreenState extends State<AIAgentScreen> {
  final TextEditingController _promptController = TextEditingController();
  final GeminiService _geminiService = GeminiService(apiKey: 'YOUR_GEMINI_API_KEY'); // TODO: Replace with actual API Key
  bool _isLoading = false;
  String _responseMessage = '';

  Future<void> _generatePlan() async {
    setState(() {
      _isLoading = true;
      _responseMessage = '';
    });

    final appData = Provider.of<AppDataProvider>(context, listen: false);
    await appData.refreshData(); // Ensure we have the latest data

    final List<Topic> allTopics = appData.topics;
    final List<UserSelection> userSelections = appData.userSelections;
    final List<StudyTask> pastFeedbackTasks = appData.studyTasks.where((task) => task.userFeedback != null && task.userFeedback!.isNotEmpty).toList();
    final String userPrompt = _promptController.text;

    if (userPrompt.isEmpty) {
      setState(() {
        _responseMessage = 'Please enter a prompt to generate a plan.';
        _isLoading = false;
      });
      return;
    }

    try {
      final List<StudyTask> generatedTasks = await _geminiService.generateStudyPlan(
        allTopics: allTopics,
        userSelections: userSelections,
        pastFeedbackTasks: pastFeedbackTasks,
        userPrompt: userPrompt,
      );

      if (generatedTasks.isNotEmpty) {
        await appData.addStudyTasks(generatedTasks);
        setState(() {
          _responseMessage = 'Study plan generated and saved successfully!';
        });
      } else {
        setState(() {
          _responseMessage = 'AI generated an empty plan. Please try again with a different prompt.';
        });
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Error generating plan: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('هوش مصنوعی (AI Agent)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'مثال: با توجه به درس‌هایی که انتخاب کردم و با فرض اینکه ۱۱ روز وقت دارم، یک برنامه روزانه برایم بساز.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _generatePlan,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('تولید برنامه'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            if (_responseMessage.isNotEmpty)
              Text(
                _responseMessage,
                style: TextStyle(
                  color: _responseMessage.startsWith('Error') ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
