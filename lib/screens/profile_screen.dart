import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../models/user_profile.dart';
import '../services/chat_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ChatService _chatService = ChatService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _valuesController;
  late TextEditingController _styleController;
  late TextEditingController _phaseController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _valuesController = TextEditingController();
    _styleController = TextEditingController();
    _phaseController = TextEditingController();
    
    _loadTheme();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valuesController.dispose();
    _styleController.dispose();
    _phaseController.dispose();
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

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _chatService.fetchProfile();
      setState(() {
        _nameController.text = profile.name ?? '';
        _valuesController.text = profile.coreValues ?? '';
        _styleController.text = profile.communicationStyle ?? '';
        _phaseController.text = profile.lifePhase ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final profile = UserProfile(
        name: _nameController.text.trim(),
        coreValues: _valuesController.text.trim(),
        communicationStyle: _styleController.text.trim(),
        lifePhase: _phaseController.text.trim(),
      );
      
      await _chatService.updateProfile(profile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF0B0F19) : const Color(0xFFDCE0E5);
    final cardColor = _isDarkMode ? const Color(0xFF1C2333) : const Color(0xFFF8F9FA);
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = _isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0);
    final accentColor = _isDarkMode ? const Color(0xFF00F3FF) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
                : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: textColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Identity", textColor),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _nameController,
                      label: "Name",
                      hint: "What should I call you?",
                      icon: Icons.person_outline,
                      cardColor: cardColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader("The Real You", textColor),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _valuesController,
                      label: "Core Values",
                      hint: "What matters most to you? (e.g. Honesty, Growth)",
                      icon: Icons.favorite_border,
                      cardColor: cardColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _styleController,
                      label: "Communication Style",
                      hint: "How do you like to talk? (e.g. Direct, Casual)",
                      icon: Icons.chat_bubble_outline,
                      cardColor: cardColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phaseController,
                      label: "Current Life Phase",
                      hint: "What's your main focus right now?",
                      icon: Icons.timeline,
                      cardColor: cardColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      borderColor: borderColor,
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 30),
                    Center(
                      child: Text(
                        "S.AI uses this to understand you better.\nIt updates automatically as we chat, but you can edit it here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: color.withOpacity(0.7),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor),
          hintText: hint,
          hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: subTextColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
