import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class SyllabusBreakdownScreen extends StatelessWidget {
  const SyllabusBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بودجه بندی دروس'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, appData, child) {
          if (appData.topics.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Group topics by subject
          final Map<String, List<Map<String, dynamic>>> groupedTopics = {};
          for (var topic in appData.topics) {
            if (!groupedTopics.containsKey(topic.subject)) {
              groupedTopics[topic.subject] = [];
            }
            groupedTopics[topic.subject]!.add({
              'name': topic.name,
              'question_count': topic.questionCount,
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: groupedTopics.entries.map((entry) {
              final subject = entry.key;
              final topics = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      ...topics.map((topic) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                topic['name'],
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            Text(
                              '${topic['question_count']} سوال',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
