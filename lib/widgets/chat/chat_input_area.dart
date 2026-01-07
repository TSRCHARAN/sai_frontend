import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'voice_visualizer.dart';
import '../../services/voice_service.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isStreaming;
  final bool isListening;
  final bool isSpeechEnabled;
  final VoidCallback onSendMessage;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;
  final VoidCallback onShowPermissionWarning;
  
  // Colors
  final Color backgroundColor;
  final Color borderColor;
  final Color surfaceColor;
  final Color textColor;
  final Color iconColor;
  final Color textSecondaryColor;
  final Color glowColor;
  final bool isDarkMode;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.isStreaming,
    required this.isListening,
    required this.isSpeechEnabled,
    required this.onSendMessage,
    required this.onStartListening,
    required this.onStopListening,
    required this.onShowPermissionWarning,
    required this.backgroundColor,
    required this.borderColor,
    required this.surfaceColor,
    required this.textColor,
    required this.iconColor,
    required this.textSecondaryColor,
    required this.glowColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: isListening ? iconColor : borderColor),
              ),
              child: isListening 
                ? Center(
                    child: VoiceVisualizer(
                      isActive: true,
                      levelStream: VoiceService().soundLevelStream,
                      color: iconColor,
                    ),
                  )
                : TextField(
                    controller: controller,
                    enabled: !(isLoading || isStreaming),
                    style: GoogleFonts.roboto(color: textColor, fontSize: 16),
                    cursorColor: iconColor,
                    decoration: InputDecoration(
                      hintText: (isLoading || isStreaming) ? "Please wait..." : "Enter command...",
                      hintStyle: GoogleFonts.roboto(color: textSecondaryColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onSubmitted: (_) => onSendMessage(),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Mic Button
          GestureDetector(
            onLongPress: isSpeechEnabled ? onStartListening : null,
            onLongPressUp: isSpeechEnabled ? onStopListening : null,
            onTap: () {
                if (!isSpeechEnabled) {
                    onShowPermissionWarning();
                } else {
                    isListening ? onStopListening() : onStartListening();
                }
            },
            child: Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: isListening ? Colors.redAccent : surfaceColor,
                 border: Border.all(color: isSpeechEnabled ? borderColor : Colors.orange.withOpacity(0.5)),
               ),
               child: Icon(
                 !isSpeechEnabled ? Icons.mic_off : (isListening ? Icons.mic : Icons.mic_none),
                 color: !isSpeechEnabled ? Colors.orange : (isListening ? Colors.white : iconColor),
               ),
            ),
          ),
          const SizedBox(width: 8),

          Opacity(
            opacity: (isLoading || isStreaming) ? 0.5 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [iconColor, glowColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.send_rounded, color: isDarkMode ? Colors.black : Colors.white),
                onPressed: (isLoading || isStreaming) ? null : onSendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
