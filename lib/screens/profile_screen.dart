import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _userService = UserService();
  final _chatService = ChatService();
  
  bool _isLoading = true;
  bool _isDarkMode = false; 
  GoogleSignInAccount? _currentUser;
  String _displayUserId = "Loading...";

  // Controllers
  final _nameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _interestsController = TextEditingController();
  final _favoritesController = TextEditingController();
  final _speechPatternsController = TextEditingController();
  final _communicationStyleController = TextEditingController();
  final _lifePhaseController = TextEditingController();
  final _coreValuesController = TextEditingController();
  final _relationshipsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initAuth();
    _loadProfile();
  }

  void _initAuth() async {
    // Listen to auth changes
    _userService.onAuthStateChanged.listen((GoogleSignInAccount? account) {
       if (mounted) {
         setState(() {
           _currentUser = account;
         });
         _updateDisplayId();
       }
    });
    
    // Initial check
    _currentUser = _userService.currentUser;
    _updateDisplayId();
  }
  
  Future<void> _updateDisplayId() async {
      final id = await _userService.getUserId();
      if (mounted) {
          setState(() {
              _displayUserId = id;
          });
          // Reload profile if ID changed
          _loadProfile();
      }
  }

  Future<void> _handleSignIn() async {
      try {
          await _userService.signInWithGoogle();
      } catch (error) {
          print(error);
      }
  }

  Future<void> _handleSignOut() async {
      // 1. Tell backend to destroy session
      final sessionId = await _userService.getSessionId();
      await _chatService.logoutBackend(sessionId);
      
      // 2. Perform local cleanup and Auth SignOut
      await _userService.signOut();
      
      if (mounted) {
         // 3. Navigate to Home/Setup to reset all UI states (Clears ChatScreen)
         Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
         );
      }
  }

  Future<void> _showPrivacyDialog(BuildContext context) async {
    showDialog(
      context: context, 
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _chatService.fetchPrivacyPolicy(),
          builder: (context, snapshot) {
            // Use fallback if loading or error
            final data = snapshot.data ?? {};
            final sections = data['sections'] as List<dynamic>?;
            final lastUpdated = data['last_updated'] as String? ?? "Offline Mode (Default Policy)";

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 // Header
                 Padding(
                   padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                   child: Row(
                     children: [
                       Icon(Icons.verified_user_outlined, color: _isDarkMode ? Colors.blueAccent : Colors.deepPurple),
                       const SizedBox(width: 12),
                       Text("Privacy Policy", style: TextStyle(
                         fontSize: 20, 
                         fontWeight: FontWeight.bold,
                         color: _isDarkMode ? Colors.white : Colors.black87
                       )),
                     ],
                   ),
                 ),
                 Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),
                 
                 // Content
                 Flexible(
                   child: SingleChildScrollView(
                     padding: const EdgeInsets.all(24),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         if (snapshot.connectionState == ConnectionState.waiting)
                            const Center(child: LinearProgressIndicator()),
                         
                         const SizedBox(height: 10),
                         Text("Last Updated: $lastUpdated", style: TextStyle(color: _isDarkMode ? Colors.white38 : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                         const SizedBox(height: 20),
                         
                         if (sections != null && sections.isNotEmpty)
                            // Render Server Content
                            ...sections.map((section) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(section['title'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                                const SizedBox(height: 8),
                                Text(
                                  section['content'], 
                                  style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 13)
                                ),
                                const SizedBox(height: 20),
                              ],
                            ))
                         else
                            // Render Fallback Content (Same as before)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text("1. Introduction", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                                 const SizedBox(height: 8),
                                 Text(
                                   "S.AI is a personal companion application committed to data sovereignty. This policy describes how we handle your information on your self-hosted instance.", 
                                   style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 13)
                                 ),
                                 const SizedBox(height: 20),

                                 Text("2. Information We Collect", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                                 const SizedBox(height: 8),
                                 Text(
                                   "• Account Data: Name and Email from Google Sign-In for authentication.\n• Usage Data: Chat messages and user preferences explicitly provided by you.\n• Derived Data: 'Memories' or insights generated by the AI to maintain conversation context.", 
                                   style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 13)
                                 ),
                                 const SizedBox(height: 20),

                                 Text("3. How We Use Info", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                                 const SizedBox(height: 8),
                                 Text(
                                   "Your data is used solely to:\n• Provide personalized AI responses.\n• Maintain conversation continuity across sessions.\n• We DO NOT sell, rent, or trade user data to advertisers.", 
                                   style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 13)
                                 ),
                                 const SizedBox(height: 20),

                                 Text("4. AI & Third Parties", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                                 const SizedBox(height: 8),
                                 Text(
                                   "Text inputs are processed by the configured LLM provider (e.g., OpenAI). Please refer to your LLM provider's policy regarding API data usage. S.AI does not send PII unless it is part of the conversation text.", 
                                   style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 13)
                                 ),
                                 const SizedBox(height: 20),

                                 Text("5. Your Rights & Deletion", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                                 const SizedBox(height: 8),
                                 Text(
                                   "You have absolute right to erasure. Using the 'Delete Account' button in this app immediately wipes your database rows, vector embeddings, and session logs associated with your ID.", 
                                   style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 13)
                                 ),
                              ],
                            )
                       ],
                     ),
                   ),
                 ),
                 
                 // Footer
                 Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade200),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       TextButton(
                         onPressed: () => Navigator.pop(context),
                         child: const Text("Close"),
                       ),
                     ],
                   ),
                 ),
              ],
            );
          }
        ),
      ),
    );
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
          _relationshipsController.text = profile.relationships ?? '';
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
        relationships: _relationshipsController.text,
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
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.blueAccent.withOpacity(0.2) : Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _isDarkMode ? Colors.blueAccent : Colors.deepPurple, size: 20),
          ),
          const SizedBox(width: 12),
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
    String? explanation,
    List<String>? suggestions,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with optional 'Why?' tooltip
          Row(
            children: [
              Text(
                label, 
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? Colors.white70 : Colors.black87
                )
              ),
              if (explanation != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: explanation,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(Icons.info_outline, size: 16, color: _isDarkMode ? Colors.white30 : Colors.grey),
                )
              ]
            ],
          ),
          const SizedBox(height: 8),
          
          // Input Field
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _isDarkMode ? Colors.white24 : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _isDarkMode ? Colors.blueAccent : Colors.deepPurple, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
              ),
              filled: true,
              fillColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            ),
          ),

          // Suggestion Chips (if provided)
          if (suggestions != null) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ActionChip(
                    label: Text(s, style: TextStyle(
                      fontSize: 11,
                      color: _isDarkMode ? Colors.white70 : Colors.black87
                    )),
                    backgroundColor: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade100,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      final currentText = controller.text.trim();
                      if (currentText.isEmpty) {
                        controller.text = s;
                      } else if (!currentText.contains(s)) {
                        controller.text = "$currentText, $s";
                      }
                    },
                  ),
                )).toList(),
              ),
            )
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
           TextButton(
             onPressed: _saveProfile, 
             child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold))
           )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intro Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isDarkMode 
                            ? [Colors.blue.shade900, Colors.purple.shade900]
                            : [Colors.deepPurple.shade50, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   "Teach S.AI who you are", 
                                   style: TextStyle(
                                     fontWeight: FontWeight.bold, 
                                     fontSize: 16,
                                     color: _isDarkMode ? Colors.white : Colors.deepPurple.shade900
                                   )
                                 ),
                                 const SizedBox(height: 4),
                                 Text(
                                   "The more you share, the better your assistant becomes at predicting your needs.",
                                   style: TextStyle(
                                     fontSize: 12,
                                     color: _isDarkMode ? Colors.white70 : Colors.deepPurple.shade700
                                   ),
                                 )
                               ],
                             )
                           ),
                           Image.asset("assets/icon/app_icon.png", width: 30, height: 30)
                        ],
                      ),
                    ),
                    
                    // Auth Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isDarkMode ? Colors.white12 : Colors.grey.shade200,
                        ),
                        boxShadow: [
                           if (!_isDarkMode) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _currentUser != null ? Icons.verified_user : Icons.cloud_off,
                                size: 20,
                                color: _currentUser != null ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentUser != null ? "Account Synced" : "Guest Mode",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white : Colors.black87
                                ),
                              ),
                              const Spacer(),
                              if (_currentUser != null)
                                Text(_currentUser!.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          
                           if (_currentUser == null) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.login, size: 18),
                                    label: const Text("Sign in with Google"),
                                    onPressed: _handleSignIn,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black87,
                                        elevation: 0,
                                        side: BorderSide(color: Colors.grey.shade300),
                                        padding: const EdgeInsets.symmetric(vertical: 12)
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Click-wrap Consent
                                Center(child: Wrap(
                                  alignment: WrapAlignment.center,
                                  children: [
                                    Text(
                                      "By continuing, you agree to the ",
                                      style: TextStyle(fontSize: 11, color: _isDarkMode ? Colors.white54 : Colors.grey.shade600),
                                    ),
                                    InkWell(
                                      onTap: () => _showPrivacyDialog(context),
                                      child: Text(
                                        "Privacy Policy",
                                        style: TextStyle(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.bold, 
                                          decoration: TextDecoration.underline,
                                          color: _isDarkMode ? Colors.white70 : Colors.blue.shade800
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ".",
                                      style: TextStyle(fontSize: 11, color: _isDarkMode ? Colors.white54 : Colors.grey.shade600),
                                    ),
                                  ],
                                ))
                           ],
                           
                           // Debug Info (Hidden by default or minimal)
                           if (_currentUser != null) ...[
                               const SizedBox(height: 12),
                               
                               // Divider for account actions
                               Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.grey.shade100),
                               
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                 children: [
                                   TextButton(
                                       onPressed: () => _showPrivacyDialog(context),
                                       child: const Text("Privacy", style: TextStyle(fontSize: 12)),
                                   ),
                                   TextButton(
                                       onPressed: _handleSignOut,
                                       child: const Text("Sign Out", style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                   ),
                                 ],
                               )
                           ],
                        ],
                      ),
                    ),

                    _buildSectionHeader("The Basics", Icons.person_outline),
                    _buildTextField(
                        _nameController, 
                        "Name", 
                        "What should I call you?", 
                        // Name is optional. If empty, AI defaults to "Friend" or "User"
                    ),
                    _buildTextField(
                        _birthdayController, 
                        "Birthday", 
                        "YYYY-MM-DD", 
                        explanation: "For age-appropriate advice and birthday wishes.",
                        validator: (val) {
                           if (val == null || val.isEmpty) return null; 
                           final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                           if (!regex.hasMatch(val)) return "Format must be YYYY-MM-DD";
                           try {
                             final date = DateTime.parse(val);
                             final now = DateTime.now();
                             if (date.isAfter(now)) return "Are you from the future?";
                             if (date.year < 1900) return "Are you really that old?";
                           } catch (e) {
                             return "Invalid date";
                           }
                           return null;
                        }
                    ),

                    _buildSectionHeader("Key People", Icons.people_outline),
                    _buildTextField(
                      _relationshipsController, 
                      "Friends & Family", 
                      "Sarah (Sister), Rahul (Best friend)...",
                      maxLines: 2,
                      explanation: "The AI helps better if it knows who 'Sarah' is.",
                      // No strict validation. We trust the AI to parse natural language.
                      // "Rahul" is fine. "Rahul my gym bro" is fine.
                    ),
                    _buildSectionHeader("Communication Style", Icons.chat_bubble_outline),
                    _buildTextField(
                      _communicationStyleController, 
                      "How should I talk?", 
                      "e.g. Concise, Warm, Formal",
                      explanation: "Defines the AI's tone of voice.",
                      suggestions: ["Direct", "Empathetic", "Humorous", "Socratic", "Formal", "Bro-style"]
                    ),
                    _buildTextField(
                      _speechPatternsController, 
                      "Your Slang / Lingo", 
                      "e.g. 'Sahi hai', 'Cool', 'Bet'",
                      explanation: "Helping the AI understand your specific vocabulary.",
                      suggestions: ["Tech jargon", "Gen-Z", "Casual Hindi-English", "Formal Business"]
                    ),

                    _buildSectionHeader("The Good Stuff", Icons.favorite_border),
                    _buildTextField(
                      _interestsController, 
                      "Interests / Hobbies", 
                      "What do you do for fun?",
                      maxLines: 2,
                      explanation: "Used to suggest relevant analogies and ideas.",
                      suggestions: ["Coding", "Hiking", "Reading Sci-Fi", "Investing", "Meditation"]
                    ),
                    _buildTextField(
                      _favoritesController, 
                      "Favorites", 
                      "Books, Movies, Quotes...",
                      maxLines: 2,
                    ),

                    _buildSectionHeader("Deep Configuration", Icons.psychology_outlined),
                    _buildTextField(
                      _lifePhaseController, 
                      "Current Life Phase", 
                      "Where are you in life?",
                      maxLines: 2,
                      explanation: "Helps context relevance (e.g. career advice vs study tips).",
                      suggestions: ["Student", "Job Hunting", "New Parent", "Building a Startup", "Retiring"]
                    ),
                    _buildTextField(
                      _coreValuesController, 
                      "Core Values", 
                      "What drives your decisions?",
                      maxLines: 2,
                      explanation: "The AI aligns its advice with these principles.",
                      suggestions: ["Honesty", "Wealth Creation", "Work-Life Balance", "Innovation", "Family First"]
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Dangerous Stuff
                    if (_currentUser != null)
                      Center(
                        child: TextButton(
                          onPressed: _handleDeleteAccount,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.withOpacity(0.8),
                          ),
                          child: const Text("Delete Account & Data", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    
                    const SizedBox(height: 50), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }
  
  Future<void> _handleDeleteAccount() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text("This sends a signal to the backend to PERMANENTLY delete your memory profile, logs, and account data. This cannot be undone."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Delete Everything")
            ),
          ],
        )
      );
      
      if (confirm == true) {
          setState(() => _isLoading = true);
          try {
             final sessId = await _userService.getSessionId();
             await _chatService.deleteAccount(sessId);
             
             // Cleanup local
             await _userService.signOut();
             
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                );
              }
          } catch (e) {
             if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting: $e"))
                );
             }
          }
      }
  }

  void _showAboutDialog(BuildContext context) {
    // Helper to build rows
    Widget buildFeatureRow(IconData icon, String title, String description) {
       return Padding(
         padding: const EdgeInsets.symmetric(vertical: 12),
         child: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                 ),
                 child: Icon(icon, size: 24, color: _isDarkMode ? Colors.blueAccent : Colors.deepPurple),
              ),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(title, style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15,
                          color: _isDarkMode ? Colors.white : Colors.black87
                       )),
                       const SizedBox(height: 4),
                       Text(description, style: TextStyle(
                          fontSize: 13, 
                          color: _isDarkMode ? Colors.white70 : Colors.grey.shade700,
                          height: 1.4
                       )),
                    ],
                 ),
              )
           ],
         ),
       );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
         child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                  Text("The S.AI Advantage", style: TextStyle(
                     fontSize: 22, 
                     fontWeight: FontWeight.bold,
                     color: _isDarkMode ? Colors.white : Colors.black87
                  )),
                  const SizedBox(height: 8),
                  Text("Proactive. Persistent. Private.", style: TextStyle(
                     color: _isDarkMode ? Colors.blueAccent : Colors.deepPurple,
                     fontWeight: FontWeight.w500,
                     letterSpacing: 0.5
                  )),
                  const SizedBox(height: 24),
                  
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                       child: Column(
                          children: [
                             buildFeatureRow(Icons.auto_awesome, "Contextual Intelligence", "I don't just chat; I understand you. I recall past discussions and preferences to make every interaction feel personal."),
                             buildFeatureRow(Icons.bolt, "Proactive Initiative", "I don't wait for prompts. I anticipate your needs, send timely nudges, and keep your momentum alive."),
                             buildFeatureRow(Icons.flag, "Goal Agent", "Turn intentions into reality. I break down complex goals into actionable steps and help you cross the finish line."),
                             buildFeatureRow(Icons.shield_outlined, "Sovereign Privacy", "Your digital life, owned by you. 100% self-hosted architecture means your data never leaves your control."),
                          ],
                       ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: _isDarkMode ? Colors.blueAccent : Colors.deepPurple,
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           padding: const EdgeInsets.symmetric(vertical: 14)
                        ),
                        child: const Text("Let's Go"),
                     ),
                  )
               ],
            ),
         ),
      )
    );
  }
}
