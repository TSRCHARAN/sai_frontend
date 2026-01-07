import 'package:flutter/material.dart';

class VoiceVisualizer extends StatefulWidget {
  final bool isActive;
  final Stream<double> levelStream;
  final Color color;

  const VoiceVisualizer({
    super.key, 
    required this.isActive,
    required this.levelStream,
    this.color = Colors.blueAccent,
  });

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer> with SingleTickerProviderStateMixin {
  double _level = 0.0;
  
  @override
  void initState() {
    super.initState();
    widget.levelStream.listen((event) {
      if (mounted) {
        setState(() => _level = event);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      width: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          // Create a wave effect by offsetting the height based on index and level
          // Center bars are taller
          double multiplier = 1.0;
          if (index == 0 || index == 4) multiplier = 0.6;
          if (index == 1 || index == 3) multiplier = 0.8;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 6,
            height: 10 + (_level * 30 * multiplier), // Min 10, Max 40
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }),
      ),
    );
  }
}
