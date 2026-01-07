import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memory.dart';
import '../services/chat_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  List<Memory> _memories = [];
  bool _isLoading = true;
  String? _error;
  bool _isDarkMode = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTheme();
    _loadMemories();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final memories = await _chatService.fetchMemories();
      // Sort by date desc
      memories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMemory(int id) async {
    try {
      await _chatService.deleteMemory(id);
      setState(() {
        _memories.removeWhere((m) => m.id == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  List<Memory> _getMemoriesByType(String type) {
    if (type == 'plan') {
       return _memories.where((m) => m.type == 'plan').toList();
    } else if (type == 'fact') {
       return _memories.where((m) => m.type == 'fact' || m.type == 'user_fact').toList();
    } else {
       return _memories.where((m) => m.type == 'summary' || m.type == 'insight').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFDCE0E5);
    final cardColor = _isDarkMode ? const Color(0xFF1C2333) : const Color(0xFFF8F9FA);
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final tabIndicatorColor = _isDarkMode ? const Color(0xFF00F3FF) : Colors.deepPurple;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Brain'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tabIndicatorColor,
          labelColor: tabIndicatorColor,
          unselectedLabelColor: textColor.withOpacity(0.5),
          tabs: const [
            Tab(text: "FACTS", icon: Icon(Icons.psychology)),
            Tab(text: "PLANS", icon: Icon(Icons.calendar_month)),
            Tab(text: "INSIGHTS", icon: Icon(Icons.lightbulb)),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: textColor))
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: textColor)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMemoryList(_getMemoriesByType('fact'), textColor, cardColor, "No facts yet."),
                    _buildMemoryList(_getMemoriesByType('plan'), textColor, cardColor, "No plans yet."),
                    _buildMemoryList(_getMemoriesByType('summary'), textColor, cardColor, "No insights yet."),
                  ],
                ),
    );
  }

  Widget _buildMemoryList(List<Memory> activeMemories, Color textColor, Color cardColor, String emptyMsg) {
    if (activeMemories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: textColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(emptyMsg, style: TextStyle(color: textColor.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeMemories.length,
      itemBuilder: (context, index) {
        final memory = activeMemories[index];
        return _buildMemoryCard(memory, textColor, cardColor);
      },
    );
  }

  Widget _buildMemoryCard(Memory memory, Color textColor, Color cardColor) {
    final subTextColor = textColor.withOpacity(0.6);
    final Color typeColor = _getTypeColor(memory.type);

    return Dismissible(
      key: Key(memory.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteMemory(memory.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withOpacity(0.1)),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.05),
               blurRadius: 4,
               offset: const Offset(0, 2),
             ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored Strip
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Date + Status (for Plans)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM d, h:mm a').format(memory.createdAt),
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (memory.type == 'plan' && memory.planStatus != null)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: _getStatusColor(memory.planStatus!).withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 memory.planStatus!.toUpperCase(),
                                 style: TextStyle(
                                   color: _getStatusColor(memory.planStatus!),
                                   fontSize: 9,
                                   fontWeight: FontWeight.bold
                                 ),
                               ),
                             ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Markdown Body
                      MarkdownBody(
                        data: memory.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                          strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          code: TextStyle(
                            backgroundColor: textColor.withOpacity(0.1),
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        onTapLink: (text, href, title) async {
                           if (href != null && await canLaunchUrl(Uri.parse(href))) {
                             await launchUrl(Uri.parse(href));
                           }
                        },
                      ),
                      
                      // Target Date Footer (if exists)
                      if (memory.targetTime != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm, size: 14, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text(
                                "Due: ${DateFormat('EEE, MMM d @ h:mm a').format(memory.targetTime!)}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'plan':
        return Colors.blueAccent;
      case 'fact':
      case 'user_fact':
        return Colors.green;
      case 'summary':
      case 'insight':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'cancelled') return Colors.red;
    return Colors.blue;
  }
}
