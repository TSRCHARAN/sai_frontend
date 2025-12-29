import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

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
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _isDarkMode = true;

  late AnimationController _fadeController;
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadTheme();
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
    Future.delayed(const Duration(milliseconds: 1000), () {
      _fadeController.forward();
      _fetchWelcomeMessage();
    });
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
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgStart, _bgEnd],
              ),
            ),
          ),
          
          // 2. Ambient Glows
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowOrb(_glowColor1),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _buildGlowOrb(_glowColor2),
          ),

          // 3. Content
          FadeTransition(
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
        ],
      ),
    );
  }

  Widget _buildGlowOrb(Color color) {
    // In light mode, we want a subtle wash, not a "lamp".
    final double opacity = _isDarkMode ? 0.15 : 0.08;
    final double blur = _isDarkMode ? 100 : 150;
    
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
            child: IconButton(
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
