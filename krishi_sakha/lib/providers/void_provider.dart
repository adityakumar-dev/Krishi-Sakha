import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'package:krishi_sakha/apis/api_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceProvider extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts(
    
  );
  final SpeechToText _speech = SpeechToText();
  String recognizedWord = "";
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;
  double speechRate = 1.0;

  bool error = false;

  String _language = 'en';
  String get language => _language;

  final List<String> _pendingTexts = [];
  String lastResponse = "";

  VoiceProvider() {
    _initializeSpeech();
    
    // listen when current utterance finishes => start next one
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      if (_pendingTexts.isNotEmpty) {
        _speakNext();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> _initializeSpeech() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          this.error = true;
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
        },
      );
      _tts.setPitch(speechRate);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize speech recognition: $e');
      error = true;
      notifyListeners();
    }
  }

  void setLanguage(String lang) {
    _language = lang;
    _tts.setLanguage(lang);
    notifyListeners();
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      await _initializeSpeech();
    }
    
    if (!_isInitialized) {
      error = true;
      notifyListeners();
      return;
    }

    recognizedWord = "";
    _isListening = true;
    notifyListeners();
    
    await _speech.listen(
      onResult: (result) {
        recognizedWord = result.recognizedWords;
        notifyListeners();
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: _language,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    notifyListeners();
    await _speech.stop();
    
    // Trigger API call if we have recognized text
    if (recognizedWord.isNotEmpty) {
      await getResponse();
    }
  }

  Future<void> getResponse() async {
    if (recognizedWord.isEmpty) return;
    
    try {
      // Clear previous response
      lastResponse = "";
      _pendingTexts.clear();
      notifyListeners();
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiManager.baseUrl + ApiManager.voiceUrl),
      );
      request.fields['prompt'] = recognizedWord;
      request.headers['Authorization'] = 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}';
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        response.stream.transform(utf8.decoder).listen(
          (data) {
       handleStreamChunk(data);
          },
          onError: (error) {
            debugPrint('Stream error: $error');
            this.error = true;
            notifyListeners();
          },
          onDone: () {
            debugPrint('Response stream completed');
          },
        );
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        error = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Request error: $e');
      error = true;
      notifyListeners();
    }
  }

  void addWord(String text) {
    // add to queue
    _pendingTexts.add(text);
    lastResponse += text;

    // if not speaking right now, start automatically
    if (!_isSpeaking) {
      _speakNext();
    }

    notifyListeners();
  }

  void _speakNext() async {
    if (_pendingTexts.isEmpty) return;

    final nextText = _pendingTexts.removeAt(0);

    try {
      _isSpeaking = true;
      await _tts.speak(nextText);
    } catch (e) {
      error = true;
      _isSpeaking = false;
      notifyListeners();
    }
  }

  void cancelSpeaking() {
    _tts.stop();
    _pendingTexts.clear();
    _isSpeaking = false;
    notifyListeners();
  }
void handleStreamChunk(String chunk) {
  if (chunk.isEmpty) return;

  final lines = chunk.split('\n');
  for (final line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) continue;

    String jsonStr = trimmedLine;
    if (jsonStr.startsWith('data: ')) {
      jsonStr = jsonStr.substring(6).trim();
    }

    if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

    // Parse JSON safely
    dynamic data;
    try {
      data = jsonDecode(jsonStr);
    } catch (_) {
      continue; // skip invalid JSON
    }

    if (data is Map<String, dynamic> && data['type'] == 'text') {
      final textChunk = data['chunk'];
      if (textChunk != null && textChunk is String) {
        addWord(textChunk.replaceAll(RegExp(r'[!@#$%^&*(),.?":{}|<>]'), '')); // this updates lastResponse and queues TTS
      }
    }
  }
}

}