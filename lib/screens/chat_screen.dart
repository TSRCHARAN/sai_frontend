import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/voice_service.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_input_area.dart';
import '../widgets/chat/chat_message_bubble.dart';
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
  final String? sessionId;
  final String? initialSystemPrompt;

  const ChatScreen({super.key, this.sessionId, this.initialSystemPrompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  
  // Voice
  final VoiceService _voiceService = VoiceService();
  StreamSubscription<bool>? _listeningSubscription;
  StreamSubscription<bool>? _speakingSubscription;
  
  bool _isListening = false;
  bool _speechEnabled = false;

  bool _isLoading = false;
  bool _isStreaming = false;
  bool _isSpeaking = false;
  DateTime? _currentlyPlayingMessageTimestamp;
  bool _isDarkMode = true;

  // Debounce for task toggles
  final Map<String, Timer> _taskDebouncers = {};

  late AnimationController _fadeController;
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen for app resume
    _loadTheme();
    
    // Voice Service Subscriptions
    _listeningSubscription = _voiceService.isListeningStream.listen((isListening) {
      if (mounted) setState(() => _isListening = isListening);
    });
    _speakingSubscription = _voiceService.isSpeakingStream.listen((isSpeaking) {
      if (mounted) {
        setState(() {
          _isSpeaking = isSpeaking;
          if (!isSpeaking) _currentlyPlayingMessageTimestamp = null;
        });
      }
    });
    
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

    // Start fade in shortly after build
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });

    // Start logic immediately
    Future.delayed(Duration.zero, () async {
      // If we have an initial system prompt (e.g. Discovery Mode), trigger it immediately
      // and SKIP the welcome message.
      if (widget.initialSystemPrompt != null) {
          _sendHiddenSystemMessage(widget.initialSystemPrompt!);
          return;
      }

      // Check if launched from notification
      bool launchedFromNotif = await _checkLaunchPayload();
      
      // Only fetch welcome if NOT launched from notification
      if (!launchedFromNotif) {
        _fetchWelcomeMessage();
      }
      
      _scheduleNotifications();
    });

    // Listen for notification taps while app is running (Local)
    NotificationService().selectNotificationStream.stream.listen((String? payload) {
      if (payload != null) {
        _handleNotificationTap(payload);
      }
    });

    // Listen for notification taps while app is in background (FCM)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Use body as payload, or data if you prefer
        final payload = message.notification?.body ?? "Reminder";
        _handleNotificationTap(payload);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceService.stop(); // Stop speaking when screen is disposed
    _listeningSubscription?.cancel();
    _speakingSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground. Sync timezone in case user traveled.
      NotificationService().syncTimezone();
    }
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

      // 2. Initialize Voice Service
      await _voiceService.init();
      
      // 3. Initialize STT
      _speechEnabled = await _voiceService.initializeSTT(
        onStatus: (status) {
          // Handled by stream
        },
        onError: (error) async {
            debugPrint('Speech Error: $error');
            
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
      );

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
            _speechEnabled = await _voiceService.initializeSTT(
                onStatus: (_) {},
                onError: (error) async {
                    debugPrint('Speech Error (Re-init): $error');
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
    
    await _voiceService.startListening(
        onResult: (text, isFinal) {
            setState(() {
                _controller.text = text;
                if (isFinal) {
                    _sendMessage(); // Auto-send on final result
                }
            });
        }
    );
  }

  void _stopListening() async {
    await _voiceService.stopListening();
  }

  Future<void> _stopSpeaking() async {
    await _voiceService.stop();
    setState(() {
      _isSpeaking = false;
      _currentlyPlayingMessageTimestamp = null;
    });
  }

  Future<void> _speak(String text, {DateTime? messageTimestamp}) async {
    if (text.isNotEmpty) {
      setState(() {
        _currentlyPlayingMessageTimestamp = messageTimestamp;
      });
      await _voiceService.speak(text);
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
    // Instead of a dialog, we directly trigger the AI conversation.
    // This feels more seamless: You tap the notification, app opens, AI talks.
    _triggerContextualAI(payload);
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
      
      await for (final chunk in _chatService.sendMessageStream(prompt, sessionId: widget.sessionId)) {
        fullText += chunk;
        
        String displayText = fullText;
        if (fullText.contains("__JSON_START__")) {
            displayText = fullText.split("__JSON_START__")[0];
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
          _scrollToBottom(force: true);
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
      
      // Speak contextual response
      String finalSpeechText = fullText;
      if (fullText.contains("__JSON_START__")) {
          finalSpeechText = fullText.split("__JSON_START__")[0];
      }
      if (_messages.isNotEmpty) {
        _speak(finalSpeechText, messageTimestamp: _messages.last.timestamp);
      }

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
      
      await for (final chunk in _chatService.getWelcomeStream(sessionId: widget.sessionId)) {
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
          _scrollToBottom(force: true);
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
      if (_messages.isNotEmpty) {
        _speak(fullText, messageTimestamp: _messages.last.timestamp);
      }

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
    _scrollToBottom(force: true);

    try {
      String fullText = "";
      bool isFirstChunk = true;
      
      await for (final chunk in _chatService.sendMessageStream(userText, sessionId: widget.sessionId)) {
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
      if (_messages.isNotEmpty) {
        _speak(finalSpeechText, messageTimestamp: _messages.last.timestamp);
      }

      // Handle Side Effects (Production Ready: Immediate Scheduling)
      if (fullText.contains("__JSON_START__")) {
          final parts = fullText.split("__JSON_START__");
          if (parts.length > 1) {
              final jsonStr = parts[1].trim();
              try {
                  final List<dynamic> insights = jsonDecode(jsonStr);
                  
                  // Check for 'schedule_local' flag
                  for (var item in insights) {
                      if (item['schedule_local'] == true && item['target_time'] != null) {
                          await NotificationService().scheduleFromBackend(
                              item['content'], 
                              item['target_time']
                          );
                      }
                  }
                  
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

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final isNearBottom = position.pixels >= position.maxScrollExtent - 200;
        
        if (force || isNearBottom) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutExpo,
          );
        }
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
                          ChatInputArea(
                            controller: _controller,
                            isLoading: _isLoading,
                            isStreaming: _isStreaming,
                            isListening: _isListening,
                            isSpeechEnabled: _speechEnabled,
                            onSendMessage: _sendMessage,
                            onStartListening: _startListening,
                            onStopListening: _stopListening,
                            onShowPermissionWarning: _showGoogleAppWarning,
                            backgroundColor: _bgStart,
                            borderColor: _borderColor,
                            surfaceColor: _surfaceColor,
                            textColor: _textColor,
                            iconColor: _iconColor,
                            textSecondaryColor: _textSecondaryColor,
                            glowColor: _glowColor1,
                            isDarkMode: _isDarkMode,
                          ),
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
                  child: ChatHeader(
                    isDarkMode: _isDarkMode,
                    isSpeaking: _isSpeaking,
                    sessionId: widget.sessionId,
                    animation: _contentFadeAnimation,
                    onStopSpeaking: _stopSpeaking,
                    onThemeToggle: () async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() {
                        _isDarkMode = !_isDarkMode;
                      });
                      prefs.setBool('isDarkMode', _isDarkMode);
                    },
                    borderColor: _borderColor,
                    backgroundColor: _bgStart,
                    textColor: _textColor,
                    iconColor: _iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }





  Widget _buildMessageList() {
    return GestureDetector(
      onTap: () {
        if (_isSpeaking) _stopSpeaking();
        FocusScope.of(context).unfocus(); // Also dismiss keyboard
      },
      child: RepaintBoundary(
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
            return ChatMessageBubble(
              message: msg,
              index: index,
              isSpeaking: _isSpeaking,
              currentlyPlayingMessageTimestamp: _currentlyPlayingMessageTimestamp,
              onStopSpeaking: _stopSpeaking,
              onSpeak: (text, timestamp) => _speak(text, messageTimestamp: timestamp),
              onTaskToggle: _handleTaskToggle,
              onTapLink: _onTapLink,
              userBubbleColor: _userBubbleColor,
              aiBubbleColor: _aiBubbleColor,
              glowColor: _glowColor1,
              borderColor: _borderColor,
              textColor: _textColor,
              surfaceColor: _surfaceColor,
              backgroundColor: _bgStart,
            );
          },
        ),
      ),
    );
  }



  void _onTapLink(String text, String? href, String title) async {
    if (href != null) {
      final Uri url = Uri.parse(href);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }



  void _handleTaskToggle(int msgIndex, String fullText, int lineIndex, String taskContent, bool newIsChecked) {
      HapticFeedback.lightImpact(); // Tactile feedback
      
      List<String> lines = fullText.split('\n');
      if (lineIndex < 0 || lineIndex >= lines.length) return;

      String line = lines[lineIndex];
      
      if (newIsChecked) {
          if (!line.contains("✅")) {
              lines[lineIndex] = "$line ✅";
          }
      } else {
          lines[lineIndex] = line.replaceAll("✅", "").trim();
      }
      
      String newText = lines.join('\n');
      
      setState(() {
          _messages[msgIndex] = ChatMessage(
              text: newText,
              isUser: false,
              timestamp: _messages[msgIndex].timestamp,
          );
      });

      // 2. Debounce Network Call
      final key = "$msgIndex-$taskContent";
      
      if (_taskDebouncers.containsKey(key)) {
          _taskDebouncers[key]!.cancel();
      }

      _taskDebouncers[key] = Timer(const Duration(seconds: 2), () {
          _taskDebouncers.remove(key);
          
          // Send System Event to Backend
          if (newIsChecked) {
             _sendHiddenSystemMessage("[SYSTEM_EVENT: User checked off task: \"$taskContent\". Congratulate them briefly and ask about the next step.]");
          } else {
             _sendHiddenSystemMessage("[SYSTEM_EVENT: User unchecked task: \"$taskContent\". Acknowledge this update silently or briefly.]");
          }
      });
  }

  void _sendHiddenSystemMessage(String systemPrompt) async {
      try {
          String fullResponse = "";
          bool isFirstChunk = true;
          
          await for (final chunk in _chatService.sendMessageStream(systemPrompt)) {
              fullResponse += chunk;
              String displayText = fullResponse;
              if (fullResponse.contains("__JSON_START__")) {
                  displayText = fullResponse.split("__JSON_START__")[0];
              }

              if (isFirstChunk) {
                  setState(() {
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
          
          if (_messages.isNotEmpty) {
            _speak(fullResponse.split("__JSON_START__")[0], messageTimestamp: _messages.last.timestamp);
          }
          
      } catch (e) {
          debugPrint("Failed to send system event: $e");
      }
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
