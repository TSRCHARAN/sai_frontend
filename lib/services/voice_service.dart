import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

class VoiceService {
  // Singleton pattern
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // State streams
  final _isListeningController = StreamController<bool>.broadcast();
  Stream<bool> get isListeningStream => _isListeningController.stream;

  final _isSpeakingController = StreamController<bool>.broadcast();
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;

  final _soundLevelController = StreamController<double>.broadcast();
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  bool _speechEnabled = false;
  bool get isSpeechEnabled => _speechEnabled;
  Timer? _ttsVisualizerTimer;

  Future<void> init() async {
    try {
      // TTS Setup
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);

      _flutterTts.setStartHandler(() {
        _isSpeakingController.add(true);
        _startTtsVisualizer();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeakingController.add(false);
        _stopTtsVisualizer();
      });

      _flutterTts.setCancelHandler(() {
        _isSpeakingController.add(false);
        _stopTtsVisualizer();
      });
      
      _flutterTts.setErrorHandler((msg) {
         debugPrint("TTS Error: $msg");
         _isSpeakingController.add(false);
         _stopTtsVisualizer();
      });

    } catch (e) {
      debugPrint("VoiceService init error: $e");
    }
  }

  void _startTtsVisualizer() {
    _ttsVisualizerTimer?.cancel();
    // Simulate speaking variations for visualizer (sine wave + random)
    int tick = 0;
    _ttsVisualizerTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      tick++;
      if (tick > 100) tick = 0;
      // Simple oscillation simulation
      final val = (tick % 10) / 10.0; 
      _soundLevelController.add(0.3 + (val * 0.4)); // Range 0.3 - 0.7
    });
  }

  void _stopTtsVisualizer() {
    _ttsVisualizerTimer?.cancel();
    _soundLevelController.add(0.0);
  }

  Future<bool> initializeSTT({
    required Function(String) onStatus,
    required Function(SpeechRecognitionError) onError,
  }) async {
      try {
        _speechEnabled = await _speech.initialize(
            onStatus: (status) {
            onStatus(status);
            if (status == 'notListening') {
                _isListeningController.add(false);
            } else if (status == 'listening') {
                _isListeningController.add(true);
            }
            },
            onError: (error) {
                onError(error);
                _isListeningController.add(false);
            },
            debugLogging: true,
        );
      } catch (e) {
          debugPrint("STT Init Error: $e");
          _speechEnabled = false;
      }
      return _speechEnabled;
  }

  Future<void> speak(String text) async {
    // Strip markdown
    final cleanText = text
        .replaceAll(RegExp(r'\*'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'http\S+'), 'link');
        
    if (cleanText.isNotEmpty) {
      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeakingController.add(false);
    _stopTtsVisualizer();
  }

  Future<void> startListening({required Function(String, bool) onResult}) async {
      await stop(); // Stop speaking before listening
      
      if (!_speechEnabled) {
          debugPrint("Cannot start listening: Speech not enabled");
          return;
      }

      try {
        await _speech.listen(
            onResult: (result) {
                onResult(result.recognizedWords, result.finalResult);
                if (result.finalResult) {
                    _isListeningController.add(false);
                }
            },
            onSoundLevelChange: (level) {
                // 'level' is usually in dB (-10 to 10 or similar ranges depending on platform)
                // Normalize roughly to 0.0 - 1.0 for UI
                // Typical dB range: -10 (quiet) to 10 (loud)
                double normalized = (level + 10) / 20.0;
                normalized = normalized.clamp(0.0, 1.0);
                _soundLevelController.add(normalized);
            },
        );
        _isListeningController.add(true);
      } catch (e) {
          debugPrint("Start listening error: $e");
          _isListeningController.add(false);
      }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _isListeningController.add(false);
    _soundLevelController.add(0.0);
  }
}
