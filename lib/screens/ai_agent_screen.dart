import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_ai/firebase_ai.dart' as fb_ai;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/chat_session.dart';
import '../models/study_task.dart';
import '../providers/app_data_provider.dart';
import '../services/ai_service.dart';

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
  late final AnimationController _fabAnimationController;
  late final AnimationController _dotAnimationController;

  late final Animation<double> _fabAnimation;
  fb_ai.ChatSession? _chatSession;
  bool _isLoading = false;
  bool _isChatStarted = false;
  bool _isInputFocused = false;
  final List<Map<String, dynamic>> _messages = [];
  bool _showScrollToBottom = false;
  double _previousScrollPosition = 0;
  StreamSubscription? _streamSubscription;
  late final stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _aiService = AIService();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _inputFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isInputFocused = _inputFocusNode.hasFocus;
        });
      }
    });
    _scrollController.addListener(() {
      final currentPosition = _scrollController.position.pixels;
      final maxPosition = _scrollController.position.maxScrollExtent;
      if (currentPosition < _previousScrollPosition &&
          maxPosition - currentPosition > 200) {
        if (mounted) {
          setState(() => _showScrollToBottom = true);
        }
      } else if (maxPosition - currentPosition < 50) {
        if (mounted) {
          setState(() => _showScrollToBottom = false);
        }
      }
      _previousScrollPosition = currentPosition;
    });
    _fabAnimationController.forward();
    _loadChatHistory();
    _speech = stt.SpeechToText();
  }

  Future<void> _loadChatHistory() async {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    await appData.refreshData(); // Ensure we have the latest data and sessions

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(
          appData.chatHistory.map((msg) {
            final messageType = msg['message_type'] as String;
            dynamic content = msg['message'];
            if (messageType == 'function_result') {
              content = json.decode(content as String);
            }
            return {
              'content': content,
              'sender': msg['sender'],
              'isError': messageType == 'error',
              'isTyping': false,
              'isFunctionCall': messageType == 'function_call',
              'isFunctionResult': messageType == 'function_result',
              'timestamp': DateTime.fromMillisecondsSinceEpoch(
                msg['timestamp'],
              ),
            };
          }),
        );
        _isChatStarted = _messages.isNotEmpty;
      });
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _fabAnimationController.dispose();
    _dotAnimationController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _resetChat() async {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    await appData.createNewChatSession('New Chat'); // Create a new session
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isChatStarted = false;
        _chatSession = null; // Reset Firebase chat session
        _messages.clear(); // Clear UI messages
      });
    }
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('چت جدید شروع شد'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _handleSubmittedMessage({String? prompt}) async {
    final String userPrompt = prompt ?? _promptController.text.trim();
    if (userPrompt.isEmpty || _isLoading) return;
    HapticFeedback.selectionClick();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _addErrorMessage(
                "اتصال اینترنت وجود ندارد. لطفاً شبکه خود را بررسی کرده و دوباره تلاش کنید.",
      );
      return;
    }
    _promptController.clear();
    _addMessage(userPrompt, 'user');

    final appData = Provider.of<AppDataProvider>(context, listen: false);

    if (_chatSession == null) {
      try {
        final history = appData.chatHistory
            .map((msg) {
              final sender = msg['sender'] as String;
              final messageText = msg['message'] as String;
              if (sender == 'user') {
                return fb_ai.Content.text(messageText);
              } else {
                return fb_ai.Content.model([fb_ai.TextPart(messageText)]);
              }
            })
            .where((c) => c.role != 'system')
            .toList();

        _chatSession = await _aiService.startChat(history: history);
        if (mounted) {
          setState(() {
            _isChatStarted = true;
          });
        }
      } catch (e) {
        _addErrorMessage(
                    "راه‌اندازی جلسه چت ناموفق بود. لطفاً از صحت تنظیمات پروژه Firebase خود اطمینان حاصل کنید.",
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _addMessage('', 'ai', isTyping: true);
      });
    }

    try {
      final stream = _aiService.sendMessage(
        chatSession: _chatSession!,
        prompt: userPrompt,
        onFunctionCall: (name, args) {
          _addMessage(
            'فراخوانی تابع: $name با آرگومان‌ها: $args',
            'system',
            isFunctionCall: true,
          );
        },
        onFunctionResult: (result) {
          _addMessage(result, 'system', isFunctionResult: true);
        },
        onGeneratePlan: _handlePlanGeneration,
        onGetWeakTopics: _handleGetWeakTopics,
      );

      var responseText = StringBuffer();
      _streamSubscription = stream.listen(
        (data) {
          responseText.write(data);
          if (mounted) {
            setState(() {
              if (_messages.isNotEmpty && _messages.last['sender'] == 'ai') {
                _messages.last['content'] = responseText.toString();
                _messages.last['isTyping'] = false;
              }
            });
          }
          _scrollToBottom();
        },
        onDone: () async {
          final finalResponse = responseText.toString();
          if (finalResponse.isNotEmpty) {
            final appData = Provider.of<AppDataProvider>(
              context,
              listen: false,
            );
            await appData.addChatMessage('ai', 'ai', finalResponse);
          }

          final currentSessionId = appData.currentChatSessionId;
          if (currentSessionId != null) {
            final currentSession = appData.chatSessions.firstWhere(
              (s) => s.id == currentSessionId,
              orElse: () => ChatSession(
                id: 0,
                title: 'New Chat',
                createdAt: DateTime.now(),
              ),
            );
            if (currentSession.title == 'New Chat' ||
                currentSession.title == 'چت پیش‌فرض') {
              final List<fb_ai.Content> initialChatContent = [
                fb_ai.Content.text(
                  _messages.firstWhere((m) => m['sender'] == 'user')['content']
                      as String,
                ),
                fb_ai.Content.model([fb_ai.TextPart(responseText.toString())]),
              ];
              final generatedTitle = await _aiService.generateChatTitle(
                initialChatContent,
              );
              await appData.updateChatSessionTitle(
                currentSessionId,
                generatedTitle,
              );
            }
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onError: (e) {
          debugPrint("[AIAgentScreen] Caught Exception: $e");
          _addErrorMessage(
                      "خطایی در سرویس هوش مصنوعی رخ داد. لطفاً تنظیمات پروژه Firebase خود (شامل صورتحساب و APIهای فعال) و اتصال شبکه خود را بررسی کنید. (جزئیات: ${e.toString()})",
          );
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } on Exception catch (e) {
      debugPrint("[AIAgentScreen] Caught Exception: $e");
      _addErrorMessage(
                  "خطایی در سرویس هوش مصنوعی رخ داد. لطفاً تنظیمات پروژه Firebase خود (شامل صورتحساب و APIهای فعال) و اتصال شبکه خود را بررسی کنید. (جزئیات: ${e.toString()})",
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        return {'status': 'موفقیت! ${tasks.length} وظیفه ایجاد شد.'};
      } else {
        return {'status': 'ایجاد برنامه ناموفق بود. هیچ وظیفه‌ای تولید نشد.'};
      }
    } catch (e) {
      return {'status': 'خطا در ایجاد برنامه: ${e.toString()}'};
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
        return {'weak_topics': 'کاربر هیچ مبحثی را به عنوان ضعیف علامت‌گذاری نکرده است.'};
      }
      return {'weak_topics': weakTopics};
    } catch (e) {
      return {'error': 'امکان بازیابی مباحث ضعیف وجود نداشت: ${e.toString()}'};
    }
  }

  Widget _buildDrawer() {
    final appData = Provider.of<AppDataProvider>(context);
    final currentSessionId = appData.currentChatSessionId;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'جلسات چت',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مکالمات خود را مدیریت کنید',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: appData.chatSessions.length,
              itemBuilder: (context, index) {
                final session = appData.chatSessions[index];
                final isSelected = session.id == currentSessionId;
                return ListTile(
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  onTap: () {
                    Navigator.pop(context); // Close the drawer
                    _switchChatSession(session.id!);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () {
                      Navigator.pop(context); // Close the drawer
                      _confirmDeleteChatSession(session);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              'چت جدید',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              _resetChat(); // This now creates a new session
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _switchChatSession(int sessionId) async {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    if (appData.currentChatSessionId != sessionId) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _messages.clear(); // Clear current messages while switching
        });
      }
      await appData.switchChatSession(sessionId);
      _chatSession = null; // Invalidate Firebase chat session to force re-init
      await _loadChatHistory(); // Load new session's history
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('به جلسه چت $sessionId تغییر یافت'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  void _confirmDeleteChatSession(ChatSession session) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('حذف جلسه چت؟'),
          content: Text(
                        'آیا از حذف جلسه چت "${session.title}" مطمئن هستید؟ این عمل قابل بازگشت نیست.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('لغو'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteChatSession(session.id!);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChatSession(int sessionId) async {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    await appData.deleteChatSession(sessionId);
    _chatSession = null; // Invalidate Firebase chat session
    await _loadChatHistory(); // Reload history (will switch to another session if current was deleted)
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('جلسه چت حذف شد'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _startVoiceInput() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'fa_IR', // Add this line for Persian support
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {}
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_text.isNotEmpty) {
        _handleSubmittedMessage(prompt: _text);
        _text = '';
      }
    }
  }

  void _addMessage(
    dynamic content,
    String sender, {
    bool isTyping = false,
    bool isError = false,
    bool isFunctionCall = false,
    bool isFunctionResult = false,
  }) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    String messageType;
    String messageContent;

    if (isTyping) {
      messageType = 'typing';
      messageContent = '';
    } else if (isError) {
      messageType = 'error';
      messageContent = content as String;
    } else if (isFunctionCall) {
      messageType = 'function_call';
      messageContent = content as String;
    } else if (isFunctionResult) {
      messageType = 'function_result';
      messageContent = json.encode(content);
    } else {
      messageType = sender;
      messageContent = content as String;
    }

    if (!isTyping) {
      appData.addChatMessage(sender, messageType, messageContent);
    }

    if (mounted) {
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
        _messages.add({
          'content': content,
          'sender': sender,
          'isError': isError,
          'isTyping': isTyping,
          'isFunctionCall': isFunctionCall,
          'isFunctionResult': isFunctionResult,
          'timestamp': DateTime.now(),
        });
      });
    }
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
        if (mounted) {
          setState(() => _showScrollToBottom = false);
        }
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
            Text('در کلیپ‌بورد کپی شد'),
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
                    'گزینه‌های پیام',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 24),
                _buildBottomSheetOption(
                  Icons.copy_all_outlined,
                  'کپی',
                  () => _copyMessage(text),
                ),
                _buildBottomSheetOption(
                  Icons.share_outlined,
                  'اشتراک‌گذاری',
                  () => _shareMessage(text),
                ),
                if (isUser)
                  _buildBottomSheetOption(
                    Icons.edit_outlined,
                    'ویرایش',
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
        title: Consumer<AppDataProvider>(
          builder: (context, appData, child) {
            String appBarTitle = 'دستیار هوش مصنوعی مطالعه';
            final currentSessionId = appData.currentChatSessionId;
            if (currentSessionId != null) {
              final session = appData.chatSessions.firstWhere(
                (s) => s.id == currentSessionId,
                orElse: () => ChatSession(
                  id: 0,
                  title: 'New Chat',
                  createdAt: DateTime.now(),
                ),
              );
              appBarTitle = session.title;
            }
            return Text(appBarTitle);
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colorScheme.primary,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'تاریخچه چت',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              foregroundColor: colorScheme.primary,
            ),
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _fabAnimation.value,
                child: IconButton(
                  icon: const Icon(Icons.add),
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
      drawer: _buildDrawer(), // Add the drawer here
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
          if (_isListening)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _text,
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black,
                  fontWeight: FontWeight.w300,
                ),
              ),
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
              animation: _fabAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _fabAnimation.value,
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
              'برنامه ریز هوشمند کنکور',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
                            'برنامه‌های مطالعاتی شخصی‌سازی شده، استراتژی‌های مرور و راهنمایی تحصیلی متناسب با نیازهای خود را دریافت کنید.',
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
        'title': 'برنامه‌ریزی مطالعه',
        'suggestions': [
          {
            'text': 'یک برنامه مطالعاتی ۷ روزه ایجاد کن',
            'icon': Icons.calendar_today_outlined,
          },
          {'text': 'به من در برنامه‌ریزی برای امتحانات نهایی کمک کن', 'icon': Icons.school_outlined},
        ],
      },
      {
        'title': 'کمک در مباحث',
        'suggestions': [
          {
            'text': 'ضعیف‌ترین مباحث من کدامند؟',
            'icon': Icons.trending_down_outlined,
          },
          {'text': 'به من در مرور فیزیک کمک کن', 'icon': Icons.science_outlined},
        ],
      },
      {
        'title': 'استراتژی‌های یادگیری',
        'suggestions': [
          {
            'text': 'نکات مطالعه برای تمرکز بهتر',
            'icon': Icons.psychology_outlined,
          },
          {
            'text': 'چگونه فرمول‌ها را به خاطر بسپارم؟',
            'icon': Icons.lightbulb_outline,
          },
        ],
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'از من بپرسید...',
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
    final isFunctionCall = message['isFunctionCall'] == true;
    final isFunctionResult = message['isFunctionResult'] == true;
    final content = message['content'];

    if (isTyping) {
      return _buildTypingIndicator();
    }

    if (isFunctionCall) {
      return _buildFunctionCallMessage(content as String?);
    }

    if (isFunctionResult) {
      return _buildFunctionResultMessage(content as Map<String, Object?>);
    }

    final text = content as String?;

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
                        child: isUser || isError
                            ? Text(
                                text ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isError
                                      ? Colors.red[700]
                                      : isUser
                                      ? Colors.white
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                  height: 1.4,
                                ),
                              )
                            : MarkdownBody(
                                data: text ?? '',
                                selectable: true,
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      p: Theme.of(context).textTheme.bodyLarge
                                          ?.copyWith(
                                            color: isUser
                                                ? Colors.white
                                                : Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                            height: 1.4,
                                            fontSize: 16,
                                          ),
                                      code: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).dividerColor.withOpacity(0.1),
                                            fontFamily: 'monospace',
                                          ),
                                      codeblockDecoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).dividerColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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

  Widget _buildFunctionResultMessage(Map<String, Object?> result) {
    final status = result['status'] as String?;
    final weakTopics = result['weak_topics'] as List?;

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'نتیجه تابع',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (status != null)
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(
                      text: 'وضعیت: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: status),
                  ],
                ),
              ),
            if (weakTopics != null) ...[
              Text(
                'ضعیف‌ترین مباحث:',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final topic in weakTopics)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                  child: Text('• $topic'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionCallMessage(String? text) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_ethernet,
              color: Theme.of(context).colorScheme.secondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text ?? '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(children: [_buildDot(0), _buildDot(1), _buildDot(2)]),
    );
  }

  Widget _buildDot(int index) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _dotAnimationController,
        curve: Interval(index * 0.2, 1.0, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'همین الان';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} دقیقه پیش';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ساعت پیش';
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
                          hintText: 'درخواست برنامه مطالعاتی یا چت...',
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
                                  _isListening ? Icons.mic : Icons.mic_outlined,
                                  color: _isListening
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.primary,
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
