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
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 24,
        right: 24,
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
            const SizedBox(width: 16),
          ],
          Hero(
            tag: 'sai_logo',
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconColor, width: 1.5),
              ),
              child: Icon(Icons.auto_awesome, color: iconColor, size: 20),
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
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
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
          if (sessionId == null)
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
