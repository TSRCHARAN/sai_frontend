import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  bool _isLoading = true;
  bool _isDarkMode = false; // Default to light, will load

  // Controllers
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _interestsController = TextEditingController();
  final _favoritesController = TextEditingController();
  final _speechPatternsController = TextEditingController();
  final _communicationStyleController = TextEditingController();
  final _lifePhaseController = TextEditingController();
  final _coreValuesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadProfile();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (prefs.containsKey('isDarkMode')) {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      } else {
        var brightness = PlatformDispatcher.instance.platformBrightness;
        _isDarkMode = brightness == Brightness.dark;
      }
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.fetchUserProfile();
      if (profile != null) {
        setState(() {
          _nameController.text = profile.name ?? '';
          _birthdayController.text = profile.birthday ?? '';
          _interestsController.text = profile.interests ?? '';
          _favoritesController.text = profile.favorites ?? '';
          _speechPatternsController.text = profile.speechPatterns ?? '';
          _communicationStyleController.text = profile.communicationStyle ?? '';
          _lifePhaseController.text = profile.lifePhase ?? '';
          _coreValuesController.text = profile.coreValues ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final newProfile = UserProfile(
        name: _nameController.text,
        birthday: _birthdayController.text,
        interests: _interestsController.text,
        favorites: _favoritesController.text,
        speechPatterns: _speechPatternsController.text,
        communicationStyle: _communicationStyleController.text,
        lifePhase: _lifePhaseController.text,
        coreValues: _coreValuesController.text,
      );

      await _profileService.updateUserProfile(newProfile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated! SAI will remember this.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: _isDarkMode ? Colors.blueAccent : Colors.deepPurple),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.deepPurple),
          hintText: hint,
          hintStyle: TextStyle(color: _isDarkMode ? Colors.white38 : Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey),
          ),
          filled: true,
          fillColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.grey[50], // Dark Slate vs Light Grey
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Help SAI know the real you.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildSectionHeader("The Basics", Icons.person_outline),
                    _buildTextField(_nameController, "Name", "What should I call you?"),
                    _buildTextField(_birthdayController, "Birthday", "YYYY-MM-DD"),

                    _buildSectionHeader("Personality & Style", Icons.chat_bubble_outline),
                    _buildTextField(
                      _speechPatternsController, 
                      "Slang / Catchphrases", 
                      "e.g. 'Sahi hai', 'Arre yaar', 'No way'",
                    ),
                    _buildTextField(
                      _communicationStyleController, 
                      "Communication Style", 
                      "e.g. Direct, Empathetic, Analytical",
                    ),

                    _buildSectionHeader("The Good Stuff", Icons.favorite_border),
                    _buildTextField(
                      _favoritesController, 
                      "Favorites", 
                      "Movies, Quotes, Books, Food...",
                      maxLines: 3,
                    ),
                    _buildTextField(
                      _interestsController, 
                      "Interests / Hobbies", 
                      "Running, Coding, Gaming...",
                      maxLines: 2,
                    ),

                    _buildSectionHeader("Deeper Context", Icons.psychology_outlined),
                    _buildTextField(
                      _lifePhaseController, 
                      "Current Life Phase", 
                      "e.g. Student, Job hunting, Checkered past...",
                      maxLines: 2,
                    ),
                    _buildTextField(
                      _coreValuesController, 
                      "Core Values", 
                      "e.g. Honesty, Hard work, Creativity",
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Save Profile"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
