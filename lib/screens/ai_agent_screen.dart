import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:share_plus/share_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/app_data_provider.dart';
import '../services/ai_service.dart';
import '../models/study_task.dart';

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({super.key});

  @override
  State<AIAgentScreen> createState() => _AIAgentScreenState();
}

class _AIAgentScreenState extends State<AIAgentScreen>
    with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  late final AIService _aiService;
  AnimationController? _fabAnimationController;
  AnimationController? _messageAnimationController;
  Animation<double>? _fabAnimation;
  ChatSession? _chatSession;
  bool _isLoading = false;
  bool _isChatStarted = false;
  bool _isInputFocused = false;
  final List<Map<String, dynamic>> _messages = [];
  bool _showScrollToBottom = false;
  double _previousScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _aiService = AIService();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController!,
        curve: Curves.elasticOut,
      ),
    );
    _inputFocusNode.addListener(() {
      setState(() {
        _isInputFocused = _inputFocusNode.hasFocus;
      });
    });
    _scrollController.addListener(() {
      final currentPosition = _scrollController.position.pixels;
      final maxPosition = _scrollController.position.maxScrollExtent;
      if (currentPosition < _previousScrollPosition &&
          maxPosition - currentPosition > 200) {
        setState(() => _showScrollToBottom = true);
      } else if (maxPosition - currentPosition < 50) {
        setState(() => _showScrollToBottom = false);
      }
      _previousScrollPosition = currentPosition;
    });
    _fabAnimationController?.forward();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _fabAnimationController?.dispose();
    _messageAnimationController?.dispose();
    super.dispose();
  }

  void _resetChat() {
    setState(() {
      _isLoading = false;
      _isChatStarted = false;
      _chatSession = null;
      _messages.clear();
    });
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New chat started'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _handleSubmittedMessage({String? prompt}) async {
    final String userPrompt = prompt ?? _promptController.text.trim();
    if (userPrompt.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _addErrorMessage(
        "No internet connection. Please check your network and try again.",
      );
      return;
    }
    _promptController.clear();
    _addMessage(userPrompt, 'user');
    if (!_isChatStarted) {
      try {
        _chatSession = await _aiService.startChat();
        setState(() {
          _isChatStarted = true;
        });
      } catch (e) {
        _addErrorMessage(
          "Failed to initialize the chat session. Please ensure your Firebase project is set up correctly.",
        );
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _addMessage('', 'ai', isTyping: true);
    });
    try {
      final aiResponse = await _aiService.sendMessage(
        chatSession: _chatSession!,
        prompt: userPrompt,
        onGeneratePlan: _handlePlanGeneration,
        onGetWeakTopics: _handleGetWeakTopics,
      );
      _addMessage(aiResponse, 'ai');
    } on Exception catch (e) {
      // Catching a more generic Exception as the specific type might vary.
      debugPrint("[AIAgentScreen] Caught Exception: $e");
      _addErrorMessage(
        "An error occurred with the AI service. Please check your Firebase project setup (including billing and enabled APIs) and your network connection. (Details: ${e.toString()})",
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, Object?>> _handlePlanGeneration({
    required int studyDays,
    int? studyHoursPerDay,
    List<String>? focusTopics,
  }) async {
    try {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      await appData.refreshData();
      final List<StudyTask> tasks = await _aiService.getStudyPlanJson(
        allTopics: appData.topics,
        userSelections: appData.userSelections,
        studyDays: studyDays,
        studyHoursPerDay: studyHoursPerDay,
        focusTopics: focusTopics,
      );
      if (tasks.isNotEmpty) {
        await appData.addStudyTasks(tasks);
        return {'status': 'Success! ${tasks.length} tasks created.'};
      } else {
        return {'status': 'Failed to create a plan. No tasks were generated.'};
      }
    } catch (e) {
      return {'status': 'Error during plan creation: ${e.toString()}'};
    }
  }

  Map<String, Object?> _handleGetWeakTopics() {
    try {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      final weakTopics = appData.userSelections
          .where((s) => !s.isStrong)
          .map((s) => appData.topics.firstWhere((t) => t.id == s.topicId).name)
          .toList();
      if (weakTopics.isEmpty) {
        return {'weak_topics': 'User has not marked any topics as weak.'};
      }
      return {'weak_topics': weakTopics};
    } catch (e) {
      return {'error': 'Could not retrieve weak topics: ${e.toString()}'};
    }
  }

  // --- The rest of the UI code remains the same ---
  // (build methods, message widgets, etc.)

  Future<void> _startVoiceInput() async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice input will be implemented soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addMessage(
    String text,
    String sender, {
    bool isTyping = false,
    bool isError = false,
  }) {
    setState(() {
      _messages.removeWhere((msg) => msg['isTyping'] == true);
      _messages.add({
        'text': text,
        'sender': sender,
        'isError': isError,
        'isTyping': isTyping,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _addErrorMessage(String errorText) {
    HapticFeedback.heavyImpact();
    _addMessage(errorText, 'ai', isError: true);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() => _showScrollToBottom = false);
      }
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareMessage(String text) {
    Share.share(text);
    HapticFeedback.lightImpact();
  }

  void _editMessage(String text) {
    _promptController.text = text;
    _inputFocusNode.requestFocus();
  }

  void _showMessageOptions(BuildContext context, String text, bool isUser) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    'Message Options',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 24),
                _buildBottomSheetOption(
                  Icons.copy_all_outlined,
                  'Copy',
                  () => _copyMessage(text),
                ),
                _buildBottomSheetOption(
                  Icons.share_outlined,
                  'Share',
                  () => _shareMessage(text),
                ),
                if (isUser)
                  _buildBottomSheetOption(
                    Icons.edit_outlined,
                    'Edit',
                    () => _editMessage(text),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('AI Study Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colorScheme.primary,
        actions: [
          AnimatedBuilder(
            animation: _fabAnimation ?? kAlwaysCompleteAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _fabAnimation?.value ?? 1.0,
                child: IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  onPressed: _isLoading ? null : _resetChat,
                  tooltip: 'New Chat',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: !_isChatStarted
                    ? _buildWelcomeMessage()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: _buildMessage(_messages[index]),
                          );
                        },
                      ),
              ),
              _buildInputArea(),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 100,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: colorScheme.primary,
                child: const Icon(Icons.arrow_downward, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _fabAnimation ?? kAlwaysCompleteAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _fabAnimation?.value ?? 1.0,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Konkur AI Study Assistant',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Get personalized study plans, review strategies, and academic guidance tailored to your needs.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).hintColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final categories = [
      {
        'title': 'Study Planning',
        'suggestions': [
          {
            'text': 'Create a 7-day study plan',
            'icon': Icons.calendar_today_outlined,
          },
          {'text': 'Help me plan for finals', 'icon': Icons.school_outlined},
        ],
      },
      {
        'title': 'Topic Assistance',
        'suggestions': [
          {
            'text': 'What are my weakest topics?',
            'icon': Icons.trending_down_outlined,
          },
          {'text': 'Help me review Physics', 'icon': Icons.science_outlined},
        ],
      },
      {
        'title': 'Learning Strategies',
        'suggestions': [
          {
            'text': 'Study tips for better focus',
            'icon': Icons.psychology_outlined,
          },
          {
            'text': 'How to remember formulas?',
            'icon': Icons.lightbulb_outline,
          },
        ],
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try asking me...',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...categories.map((category) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  category['title'] as String,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: (category['suggestions'] as List).map<Widget>((
                  suggestion,
                ) {
                  return GestureDetector(
                    onTap: () => _handleSubmittedMessage(
                      prompt: suggestion['text'] as String,
                    ),
                    child: Chip(
                      avatar: Icon(
                        suggestion['icon'] as IconData,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        suggestion['text'] as String,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['sender'] == 'user';
    final isTyping = message['isTyping'] == true;
    final isError = message['isError'] == true;
    final text = message['text'] as String?;
    if (isTyping) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypingIndicator(),
                    const SizedBox(width: 12),
                    Text(
                      'Thinking...',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onLongPress: () {
        if (text != null && text.isNotEmpty && !isError) {
          _showMessageOptions(context, text, isUser);
        }
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              CustomPaint(
                painter: isUser
                    ? UserMessageTailPainter(
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : AIMessageTailPainter(color: Theme.of(context).cardColor),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red[50]
                        : isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      topRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isError
                        ? Border.all(color: Colors.red[200]!, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isError) ...[
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          text ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: isError
                                ? Colors.red[700]
                                : isUser
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message['timestamp'] != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: 6,
                    left: isUser ? 0 : 16,
                    right: isUser ? 16 : 0,
                  ),
                  child: Text(
                    _formatTimestamp(message['timestamp'] as DateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return SizedBox(
      width: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [_buildDot(0), _buildDot(1), _buildDot(2)],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  Widget _buildInputArea() {
    final hasText = _promptController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    if (_isInputFocused)
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        focusNode: _inputFocusNode,
                        maxLines: null,
                        minLines: 1,
                        maxLength: 1000,
                        onChanged: (value) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Ask for a study plan or chat...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _handleSubmittedMessage(),
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: hasText
                            ? IconButton(
                                key: const ValueKey('send_button'),
                                icon: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.send_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                onPressed: _isLoading
                                    ? null
                                    : () => _handleSubmittedMessage(),
                                padding: EdgeInsets.zero,
                                splashRadius: 20,
                              )
                            : IconButton(
                                key: const ValueKey('voice_button'),
                                icon: Icon(
                                  Icons.mic_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: _startVoiceInput,
                                padding: EdgeInsets.zero,
                                splashRadius: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIMessageTailPainter extends CustomPainter {
  final Color color;
  AIMessageTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height - 10);
    path.lineTo(10, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserMessageTailPainter extends CustomPainter {
  final Color color;
  UserMessageTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(size.width, size.height - 10);
    path.lineTo(size.width - 10, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
