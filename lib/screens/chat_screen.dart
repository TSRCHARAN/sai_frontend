import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import 'memory_screen.dart';
import 'profile_screen.dart';

class ChatBackground extends StatelessWidget {
  final bool isDarkMode;

  const ChatBackground({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bgStart = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final bgEnd = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final glowColor1 = isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA);
    final glowColor2 = isDarkMode ? const Color(0xFF8B5CF6) : const Color(0xFFA78BFA);

    return Stack(
      children: [
        // 1. Gradient Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgStart, bgEnd],
            ),
          ),
        ),
        
        // 2. Ambient Glows
        Positioned(
          top: -100,
          right: -100,
          child: _buildGlowOrb(glowColor1, isDarkMode),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: _buildGlowOrb(glowColor2, isDarkMode),
        ),
      ],
    );
  }

  Widget _buildGlowOrb(Color color, bool isDark) {
    final double opacity = isDark ? 0.15 : 0.08;
    final double blur = isDark ? 100 : 150;
    
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity),
            blurRadius: blur,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  
  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _speechEnabled = false;

  bool _isLoading = false;
  bool _isStreaming = false;
  bool _isDarkMode = true;

  late AnimationController _fadeController;
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initVoice();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Start fade in after the Hero transition (approx 1000ms)
    Future.delayed(const Duration(milliseconds: 1000), () async {
      _fadeController.forward();
      
      // Check if launched from notification
      bool launchedFromNotif = await _checkLaunchPayload();
      
      // Only fetch welcome if NOT launched from notification
      // (If launched from notification, the dialog/interaction takes precedence)
      if (!launchedFromNotif) {
        _fetchWelcomeMessage();
      }
      
      _scheduleNotifications();
    });

    // Listen for notification taps while app is running
    NotificationService().selectNotificationStream.stream.listen((String? payload) {
      if (payload != null) {
        _handleNotificationTap(payload);
      }
    });
  }

  void _initVoice() async {
    try {
      // 1. Request Microphone Permission
      var status = await Permission.microphone.request();
      
      if (status.isPermanentlyDenied) {
        debugPrint("Microphone permission permanently denied");
        return;
      }

      if (!status.isGranted) {
        debugPrint("Microphone permission denied");
        return;
      }

      // 2. Initialize Speech Service
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) async {
            debugPrint('Speech Error: $error');
            setState(() => _isListening = false);
            
            // Handle "error_permission" specifically
            if (error.errorMsg.contains('error_permission')) {
                // Check if it's the App's permission or the System's
                if (await Permission.microphone.isGranted) {
                    // App has permission, so it's the System (Google App)
                    if (mounted) {
                        _showGoogleAppWarning();
                    }
                } else {
                    _showPermissionDialog();
                }
            }
        },
        debugLogging: true, // Enable debug logs for more info
      );
      
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      
      setState(() {});
    } catch (e) {
      debugPrint("Voice init error: $e");
    }
  }

  void _showGoogleAppWarning() {
      final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final String message = isIOS
        ? "On iPhone (iOS), voice needs TWO permissions:\n"
          "1) Microphone\n"
          "2) Speech Recognition\n\n"
          "If you tapped ‘Don’t Allow’ earlier:\n"
          "Settings → Privacy & Security → Microphone → enable S.AI\n"
          "Settings → Privacy & Security → Speech Recognition → enable S.AI\n\n"
          "Then return to the app and try the mic again."
        : "Voice needs Google’s Speech + TTS services (not just this app’s permission).\n\n"
          "Fix steps (Android):\n"
          "1) Settings → Apps → Manage apps → Google → Permissions → Microphone → Allow\n"
          "2) Settings → Apps → Default apps → Voice input → select ‘Speech Services by Google’\n"
          "3) Settings → Accessibility (or System) → Text-to-speech output → select ‘Google Text-to-speech engine’\n\n"
          "MIUI/Xiaomi tip: also check Google app Battery saver/Background restrictions and set to ‘No restrictions’.\n\n"
          "If ‘Speech Services by Google’ / ‘Google Text-to-speech’ is missing, install/enable it from Play Store.";

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
        title: Text(isIOS ? "Voice Permissions" : "Speech Service Error"),
        content: Text(message),
            actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK"),
                ),
            ],
        ),
    );
  }

  void _showPermissionDialog() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: const Text("Microphone Permission"),
            content: const Text("S.AI needs microphone access to hear you. Please enable it in settings."),
            actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                ),
                TextButton(
                    onPressed: () {
                        Navigator.pop(ctx);
                        openAppSettings();
                    },
                    child: const Text("Open Settings"),
                ),
            ],
        ),
    );
  }

  void _startListening() async {
    // Check permission again before starting
    var status = await Permission.microphone.status;
    if (status.isPermanentlyDenied || status.isDenied) {
        // Try to request one last time or show settings
        status = await Permission.microphone.request();
        if (status.isPermanentlyDenied) {
            _showPermissionDialog();
            return;
        }
    }

    if (!_speechEnabled) {
        // Try initializing again if it failed before
        try {
            _speechEnabled = await _speech.initialize(
                onError: (error) async {
                    debugPrint('Speech Error (Re-init): $error');
                    setState(() => _isListening = false);
                    if (error.errorMsg.contains('permission')) {
                        var status = await Permission.microphone.status;
                        if (!status.isGranted) {
                            _showPermissionDialog();
                        }
                    }
                }
            );
        } catch (e) {
            debugPrint("Re-init failed: $e");
        }
    }
    
    if (!_speechEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not initialize speech recognition. Check permissions.")),
        );
        return;
    }
    
    // Stop TTS if speaking
    await _flutterTts.stop();

    try {
        await _speech.listen(
        onResult: (result) {
            setState(() {
            _controller.text = result.recognizedWords;
            if (result.finalResult) {
                _isListening = false;
                _sendMessage(); // Auto-send on final result
            }
            });
        },
        );
        setState(() => _isListening = true);
    } catch (e) {
        debugPrint("Listen error: $e");
        setState(() => _isListening = false);
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    // Strip markdown for speech
    final cleanText = text
        .replaceAll(RegExp(r'\*'), '') // Remove bold/italic markers
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove system tags
        .replaceAll(RegExp(r'http\S+'), 'link'); // Replace URLs
        
    if (cleanText.isNotEmpty) {
      await _flutterTts.speak(cleanText);
    }
  }

  Future<bool> _checkLaunchPayload() async {
    final response = await NotificationService().getLaunchNotification();
    if (response != null && response.payload != null) {
      // Check if we already handled this specific notification ID
      final prefs = await SharedPreferences.getInstance();
      final lastHandledId = prefs.getInt('last_handled_notification_id');
      
      // If the ID is different (or null), handle it and save the new ID
      if (lastHandledId != response.id) {
        if (response.id != null) {
           await prefs.setInt('last_handled_notification_id', response.id!);
        }
        _handleNotificationTap(response.payload!);
        return true;
      }
    }
    return false;
  }

  void _handleNotificationTap(String payload) {
    // Show a dialog with the payload
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reminder"),
        content: Text(payload),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Trigger Contextual AI Response
              _triggerContextualAI(payload);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _triggerContextualAI(String payload) async {
    if (_isLoading || _isStreaming) return;

    setState(() {
      _isLoading = true;
      _isStreaming = false;
    });

    // We send a "System Prompt" disguised as a user message, 
    // but we don't add it to the UI _messages list.
    // This makes it look like the AI initiated the conversation.
    final prompt = "[SYSTEM_EVENT: The user just opened a notification for this reminder: \"$payload\". As S.AI, their supportive companion, acknowledge this warmly. Offer encouragement or ask if they need any support, but keep it natural and brief. Do not be pushy.]";

    try {
      String fullText = "";
      bool isFirstChunk = true;
      
      await for (final chunk in _chatService.sendMessageStream(prompt)) {
        fullText += chunk;
        
        if (isFirstChunk) {
          setState(() {
            _isLoading = false;
            _isStreaming = true;
            _messages.add(ChatMessage(
              text: fullText,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          isFirstChunk = false;
        } else {
          setState(() {
            _messages.last = ChatMessage(
              text: fullText,
              isUser: false,
              timestamp: _messages.last.timestamp,
            );
          });
        }
        _scrollToBottom();
      }
      
      // Speak contextual response
      _speak(fullText);

    } catch (e) {
      debugPrint("Contextual AI failed: $e");
      // Fallback if network fails
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "I see you have a reminder: \"$payload\". Let me know if you need help!",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });
      }
    }
  }

  Future<void> _scheduleNotifications() async {
    try {
      // Fetch all memories to find upcoming events
      final memories = await _chatService.fetchMemories();
      final now = DateTime.now();

      // NOTE: Do NOT cancelAll() here.
      // In production, users may create reminders immediately after opening the app.
      // cancelAll() can race and wipe newly scheduled reminders before they fire.

      for (var memory in memories) {
        if (memory.targetTime != null && memory.targetTime!.isAfter(now)) {
          // Schedule for the exact time
          // Or maybe 15 mins before? Let's do exact time for now as per user request "meeting in 30 min"
          
          String title = memory.type == 'plan' ? "Time for your plan!" : "Reminder";
          String body = memory.content;
          
          // Simple heuristic for "Warm Wish" vs "Reminder"
          if (body.toLowerCase().contains('meeting') || body.toLowerCase().contains('interview')) {
             title = "Good luck! 🌟";
             body = "You've got this: ${memory.content}";
          } else if (body.toLowerCase().contains('study') || body.toLowerCase().contains('focus')) {
             title = "Time to focus 🧠";
          }

          await NotificationService().scheduleNotification(
            id: memory.id,
            title: title,
            body: body,
            scheduledTime: memory.targetTime!,
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to schedule notifications: $e");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (prefs.containsKey('isDarkMode')) {
        _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      } else {
        var brightness = PlatformDispatcher.instance.platformBrightness;
        _isDarkMode = brightness == Brightness.dark;
      }
    });
  }

  // Theme Getters
  // Background
  Color get _bgStart => _isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFDCE0E5); // Soft Silver
  Color get _bgEnd => _isDarkMode ? const Color(0xFF111625) : const Color(0xFFEDF0F2);   // Pale Grey
  
  // Glows (Aurora vs Neon)
  Color get _glowColor1 => _isDarkMode ? const Color(0xFFBC13FE) : const Color(0xFF6366F1); // Neon Purple vs Indigo
  Color get _glowColor2 => _isDarkMode ? const Color(0xFF00F3FF) : const Color(0xFF3B82F6); // Neon Cyan vs Blue
  
  // UI Elements
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF1C2333) : const Color(0xFFF8F9FA); // Off-white surface
  Color get _userBubbleColor => _isDarkMode ? const Color(0xFF2D3447) : const Color(0xFF2563EB);
  Color get _aiBubbleColor => _isDarkMode ? const Color(0xFF1C2333) : const Color(0xFFFFFFFF);
  
  // Text & Borders
  Color get _textColor => _isDarkMode ? Colors.white : const Color(0xFF1E293B);
  Color get _textSecondaryColor => _isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
  Color get _borderColor => _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0);
  Color get _iconColor => _isDarkMode ? const Color(0xFF00F3FF) : const Color(0xFF2563EB);

  void _fetchWelcomeMessage() async {
    setState(() {
      _isLoading = true;
      _isStreaming = false;
    });

    try {
      String fullText = "";
      bool isFirstChunk = true;
      
      await for (final chunk in _chatService.getWelcomeStream()) {
        fullText += chunk;
        
        if (isFirstChunk) {
          setState(() {
            _isLoading = false;
            _isStreaming = true;
            _messages.add(ChatMessage(
              text: fullText,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          isFirstChunk = false;
        } else {
          setState(() {
            _messages.last = ChatMessage(
              text: fullText,
              isUser: false,
              timestamp: _messages.last.timestamp,
            );
          });
        }
        _scrollToBottom();
      }
      
      // Speak welcome
      _speak(fullText);

    } catch (e) {
      // If welcome fails, just show a generic greeting locally or do nothing
      if (_messages.isEmpty) {
         setState(() {
            _messages.add(ChatMessage(
              text: "Hey! Ready to chat?",
              isUser: false,
              timestamp: DateTime.now(),
            ));
         });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
        });
      }
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading || _isStreaming) return;

    final userText = _controller.text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _isStreaming = false;
    });
    _scrollToBottom();

    try {
      String fullText = "";
      bool isFirstChunk = true;
      
      await for (final chunk in _chatService.sendMessageStream(userText)) {
        fullText += chunk;
        
        String displayText = fullText;
        if (fullText.contains("__JSON_START__")) {
            if (kDebugMode) {
                // In debug mode, show the raw JSON so we know it arrived
                displayText = fullText;
            } else {
                displayText = fullText.split("__JSON_START__")[0];
            }
        }
        
        if (isFirstChunk) {
          setState(() {
            _isLoading = false;
            _isStreaming = true;
            _messages.add(ChatMessage(
              text: displayText,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          isFirstChunk = false;
        } else {
          setState(() {
            _messages.last = ChatMessage(
              text: displayText,
              isUser: false,
              timestamp: _messages.last.timestamp,
            );
          });
        }
        _scrollToBottom();
      }

      // Speak the response
      String finalSpeechText = fullText;
      if (fullText.contains("__JSON_START__")) {
          finalSpeechText = fullText.split("__JSON_START__")[0];
      }
      _speak(finalSpeechText);

      // Handle Side Effects (Production Ready: Immediate Scheduling)
      if (fullText.contains("__JSON_START__")) {
          final parts = fullText.split("__JSON_START__");
          if (parts.length > 1) {
              final jsonStr = parts[1].trim();
              try {
                  final List<dynamic> insights = jsonDecode(jsonStr);
                  await NotificationService.scheduleFromInsights(insights);
                  
                  if (mounted && insights.isNotEmpty) {
                      bool hasTime = insights.any((i) => i['target_time'] != null);
                      if (hasTime) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Reminder scheduled! ⏰")),
                        );
                      }
                  }
              } catch (e) {
                  debugPrint("Error parsing insights: $e");
              }
          }
      }
    } catch (e) {
      setState(() {
        if (_isStreaming) {
           _messages.last = ChatMessage(
            text: _messages.last.text + "\n[Connection Error: $e]",
            isUser: false,
            timestamp: _messages.last.timestamp,
          );
        } else {
          _messages.add(ChatMessage(
            text: "[Connection Error: $e]",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isStreaming = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutExpo,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Background (Static, ignores keyboard)
        Positioned.fill(
          child: ChatBackground(isDarkMode: _isDarkMode),
        ),

        // 2. Scaffold (Handles resizing for input)
        Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true, // Native smooth animation
          body: FadeTransition(
            opacity: _contentFadeAnimation,
            child: Stack(
              children: [
                // Body (Messages + Input)
                SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        children: [
                          Expanded(child: _buildMessageList()),
                          if (_isLoading) _buildTypingIndicator(),
                          _buildInputArea(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Header (Floating Glass)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowOrb(Color color) {
    // This method is now unused in ChatScreenState as it moved to ChatBackground
    // But we keep it if needed for other parts, or remove it.
    // For now, I will remove it to avoid confusion since it's in ChatBackground.
    return const SizedBox.shrink();
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor)),
        color: _bgStart, // Solid color, no transparency
      ),
      child: Row(
        children: [
          Hero(
            tag: 'sai_logo',
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _iconColor, width: 1.5),
              ),
              child: Icon(Icons.auto_awesome, color: _iconColor, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Hero(
            tag: 'sai_text',
            child: Material(
              color: Colors.transparent,
              child: Text(
                "S.AI",
                style: GoogleFonts.orbitron(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.person_outline, color: _textColor),
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.memory, color: _iconColor),
                  tooltip: 'Memories',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemoryScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: _textColor,
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    setState(() {
                  _isDarkMode = !_isDarkMode;
                });
                prefs.setBool('isDarkMode', _isDarkMode);
              },
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return RepaintBoundary(
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 90, // Offset for floating header
          bottom: 20,
          left: 16,
          right: 16,
        ),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return _buildMessageBubble(msg);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? _userBubbleColor : _aiBubbleColor, // Solid colors
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser 
                ? _glowColor1.withOpacity(0.5) 
                : _borderColor,
            width: 1,
          ),
          // Removed BoxShadow for performance during keyboard animation
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.roboto(
                  color: isUser ? Colors.white : _textColor,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
                code: GoogleFonts.robotoMono(
                  backgroundColor: isUser ? Colors.white.withOpacity(0.1) : _surfaceColor,
                  color: isUser ? Colors.white : _textColor,
                  fontSize: 13,
                ),
                codeblockDecoration: BoxDecoration(
                  color: isUser ? Colors.black.withOpacity(0.2) : _bgStart,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
              style: GoogleFonts.roboto(
                color: (isUser ? Colors.white : _textColor).withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _aiBubbleColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: _borderColor, width: 1),
            // Removed BoxShadow for performance
          ),
          child: _TypingDots(color: _iconColor),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgStart, // Solid background
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor, // Solid surface color
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _borderColor),
              ),
              child: TextField(
                controller: _controller,
                enabled: !(_isLoading || _isStreaming),
                style: GoogleFonts.roboto(color: _textColor, fontSize: 16), // Readable font
                cursorColor: _iconColor,
                decoration: InputDecoration(
                  hintText: (_isLoading || _isStreaming) ? "Please wait..." : "Enter command...",
                  hintStyle: GoogleFonts.roboto(color: _textSecondaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Mic Button
          GestureDetector(
            onLongPress: _speechEnabled ? _startListening : null,
            onLongPressUp: _speechEnabled ? _stopListening : null,
            onTap: () {
                if (!_speechEnabled) {
                    _showGoogleAppWarning();
                } else {
                    _isListening ? _stopListening() : _startListening();
                }
            },
            child: Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: _isListening ? Colors.redAccent : _surfaceColor,
                 border: Border.all(color: _speechEnabled ? _borderColor : Colors.orange.withOpacity(0.5)),
               ),
               child: Icon(
                 !_speechEnabled ? Icons.mic_off : (_isListening ? Icons.mic : Icons.mic_none),
                 color: !_speechEnabled ? Colors.orange : (_isListening ? Colors.white : _iconColor),
               ),
            ),
          ),
          const SizedBox(width: 8),

          Opacity(
            opacity: (_isLoading || _isStreaming) ? 0.5 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_iconColor, _glowColor1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.send_rounded, color: _isDarkMode ? Colors.black : Colors.white),
                onPressed: (_isLoading || _isStreaming) ? null : _sendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double opacity = _getOpacity(index);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  double _getOpacity(int index) {
    final double t = _controller.value;
    final double start = index * 0.2;
    final double end = start + 0.4;
    
    if (t >= start && t <= end) {
      return 1.0; // Active
    } else {
      return 0.3; // Dimmed
    }
  }
}
