import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';
import '../models/user_selection.dart';

class MySubjectsScreen extends StatefulWidget {
  const MySubjectsScreen({super.key});

  @override
  State<MySubjectsScreen> createState() => _MySubjectsScreenState();
}

class _MySubjectsScreenState extends State<MySubjectsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('درس های من'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, appData, child) {
          if (appData.topics.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: appData.getTopicsWithUserSelection(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('خطا: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('مبحثی در دسترس نیست.'));
              }

              final topicsWithSelection = snapshot.data!;

              // Group topics by subject
              final Map<String, List<Map<String, dynamic>>> groupedTopics = {};
              for (var topicData in topicsWithSelection) {
                final subject = topicData['subject'];
                if (!groupedTopics.containsKey(subject)) {
                  groupedTopics[subject] = [];
                }
                groupedTopics[subject]!.add(topicData);
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
                          ...topics.map((topicData) {
                            final topicId = topicData['id'];
                            final topicName = topicData['name'];
                            bool isStrong = topicData['is_strong'] == 1;

                            return CheckboxListTile(
                              title: Text(topicName),
                              value: isStrong,
                              onChanged: (bool? newValue) async {
                                if (newValue != null) {
                                  final selection = UserSelection(
                                    topicId: topicId,
                                    isStrong: newValue,
                                  );
                                  await appData.updateUserSelection(selection);
                                }
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
