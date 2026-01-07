import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;
  final bool isSpeaking;
  final DateTime? currentlyPlayingMessageTimestamp;
  final VoidCallback onStopSpeaking;
  final Function(String, DateTime) onSpeak;
  final Function(int, String, int, String, bool) onTaskToggle;
  final Function(String, String?, String) onTapLink;
  
  // Colors
  final Color userBubbleColor;
  final Color aiBubbleColor;
  final Color glowColor;
  final Color borderColor;
  final Color textColor;
  final Color surfaceColor;
  final Color backgroundColor;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.index,
    required this.isSpeaking,
    this.currentlyPlayingMessageTimestamp,
    required this.onStopSpeaking,
    required this.onSpeak,
    required this.onTaskToggle,
    required this.onTapLink,
    required this.userBubbleColor,
    required this.aiBubbleColor,
    required this.glowColor,
    required this.borderColor,
    required this.textColor,
    required this.surfaceColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? userBubbleColor : aiBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(
            color: isUser 
                ? glowColor.withOpacity(0.5) 
                : borderColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRichMessage(message, index),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                  style: GoogleFonts.roboto(
                    color: (isUser ? Colors.white : textColor).withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (isSpeaking && currentlyPlayingMessageTimestamp == message.timestamp) {
                        onStopSpeaking();
                      } else {
                        onSpeak(message.text, message.timestamp);
                      }
                    },
                    child: Icon(
                      (isSpeaking && currentlyPlayingMessageTimestamp == message.timestamp)
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined,
                      size: 14,
                      color: textColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichMessage(ChatMessage msg, int index) {
    if (msg.isUser) {
      return MarkdownBody(
        data: msg.text,
        styleSheet: _markdownStyle(true),
        onTapLink: onTapLink,
      );
    }

    List<Widget> children = [];
    List<String> lines = msg.text.split('\n');
    bool hasList = false;

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      final taskMatch = RegExp(r'^(\s*)([\-\*]|\d+\.)\s+(.+)$').firstMatch(line);
      
      if (taskMatch != null) {
        hasList = true;
        String indent = taskMatch.group(1) ?? "";
        String content = taskMatch.group(3) ?? "";
        bool isChecked = content.trim().endsWith("✅");
        String cleanContent = isChecked ? content.replaceAll("✅", "").trim() : content;

        children.add(
           Padding(
             padding: const EdgeInsets.only(bottom: 4.0),
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  if (indent.isNotEmpty) SizedBox(width: 16.0), 
                  SizedBox(
                    width: 24, 
                    height: 24,
                    child: Checkbox(
                      value: isChecked,
                      activeColor: glowColor,
                      side: BorderSide(color: borderColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                         if (val != null) {
                            onTaskToggle(index, msg.text, i, cleanContent, val);
                         }
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                     child: MarkdownBody(
                        data: isChecked ? "~$cleanContent~" : cleanContent,
                        styleSheet: _markdownStyle(false),
                        onTapLink: onTapLink,
                     )
                  )
               ]
             ),
           )
        );
      } else {
        if (line.trim().isNotEmpty) {
            children.add(
                Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: MarkdownBody(
                        data: line,
                        styleSheet: _markdownStyle(false),
                        onTapLink: onTapLink,
                    ),
                )
            );
        }
      }
    }

    if (!hasList) {
        return MarkdownBody(
            data: msg.text,
            styleSheet: _markdownStyle(false),
            onTapLink: onTapLink,
        );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  MarkdownStyleSheet _markdownStyle(bool isUser) {
    return MarkdownStyleSheet(
        p: GoogleFonts.roboto(
            color: isUser ? Colors.white : textColor,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w400,
        ),
        code: GoogleFonts.robotoMono(
            backgroundColor: isUser ? Colors.white.withOpacity(0.1) : surfaceColor,
            color: isUser ? Colors.white : textColor,
            fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
            color: isUser ? Colors.black.withOpacity(0.2) : backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
        ),
    );
  }
}
