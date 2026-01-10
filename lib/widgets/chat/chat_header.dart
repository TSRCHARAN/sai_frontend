import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/profile_screen.dart';
import '../../screens/memory_screen.dart';

class ChatHeader extends StatelessWidget {
  final bool isDarkMode;
  final bool isSpeaking;
  final String? sessionId;
  final Animation<double> animation;
  final VoidCallback onStopSpeaking;
  final VoidCallback onThemeToggle;
  final VoidCallback? onTitleTap;
  
  // Colors
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;

  const ChatHeader({
    super.key,
    required this.isDarkMode,
    required this.isSpeaking,
    this.sessionId,
    required this.animation,
    required this.onStopSpeaking,
    required this.onThemeToggle,
    this.onTitleTap,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
        color: backgroundColor,
      ),
      child: Row(
        children: [
          if (Navigator.canPop(context) && sessionId != null) ...[
            IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
              onPressed: () {
                onStopSpeaking();
                Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          
          // Clickable Logo/Title Area
          InkWell(
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'sai_logo',
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          "assets/icon/app_icon.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Hero(
                      tag: 'sai_text',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          "S.AI",
                          style: GoogleFonts.orbitron(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          overflow: TextOverflow.fade,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          if (isSpeaking)
            FadeTransition(
              opacity: animation,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: onStopSpeaking,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          "Stop",
                          style: GoogleFonts.roboto(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // if (sessionId == null) <--- Removed checking for null session, show icons always
            FadeTransition(
              opacity: animation,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.person_outline, color: textColor),
                    tooltip: 'Profile',
                    onPressed: () {
                      onStopSpeaking();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.memory, color: iconColor),
                    tooltip: 'Memories',
                    onPressed: () {
                      onStopSpeaking();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MemoryScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: textColor,
                    ),
                    onPressed: onThemeToggle,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
