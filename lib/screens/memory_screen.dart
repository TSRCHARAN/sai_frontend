import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import '../services/chat_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final ChatService _chatService = ChatService();
  List<Memory> _memories = [];
  bool _isLoading = true;
  String? _error;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadMemories();
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

  @override
  Widget build(BuildContext context) {
    // Theme Colors (Matching ChatScreen)
    final bgColor = _isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFDCE0E5);
    final cardColor = _isDarkMode ? const Color(0xFF1C2333) : const Color(0xFFF8F9FA);
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = _isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Memories'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: textColor))
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: textColor)))
              : _memories.isEmpty
                  ? Center(child: Text('No memories yet.', style: TextStyle(color: subTextColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _memories.length,
                      itemBuilder: (context, index) {
                        final memory = _memories[index];
                        return Dismissible(
                          key: Key(memory.id.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            _deleteMemory(memory.id);
                          },
                          child: Card(
                            color: cardColor,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: borderColor),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Colored Strip
                                  Container(
                                    width: 4,
                                    color: _getTypeColor(memory.type),
                                  ),
                                  // Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Main Content & Delete
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  memory.content,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 15,
                                                    height: 1.3,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _deleteMemory(memory.id),
                                                child: Icon(Icons.close, size: 18, color: subTextColor.withOpacity(0.5)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Metadata Footer
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              // Type Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getTypeColor(memory.type).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  memory.type.toUpperCase(),
                                                  style: TextStyle(
                                                    color: _getTypeColor(memory.type),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              // Created Date
                                              Text(
                                                DateFormat('MMM d, h:mm a').format(memory.createdAt),
                                                style: TextStyle(color: subTextColor, fontSize: 11),
                                              ),
                                              // Target Time Pill
                                              if (memory.targetTime != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.event_available, size: 10, color: Colors.orange),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        DateFormat('MMM d, h:mm a').format(memory.targetTime!),
                                                        style: const TextStyle(
                                                          color: Colors.orange,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'plan':
        return Colors.blue;
      case 'fact':
        return Colors.green;
      case 'summary':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
