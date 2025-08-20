import 'package:flutter/material.dart';
import 'package:krishi_sakha/providers/void_provider.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:provider/provider.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: AppColors.primaryBlack,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text("Voice Chat", style: TextStyle(color: Colors.white)),
            
          ),
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Expanded area for AI response or recognized text
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Show error message if there's an error
                            if (provider.error)
                              Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.redAccent,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Something went wrong. Please try again.",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      provider.error = false;
                                      provider.lastResponse = "";
                                      provider.recognizedWord = "";
                                      provider.notifyListeners();
                                    },
                                    child: const Text("Try Again"),
                                  ),
                                ],
                              )
                            // Show initialization status
                            else if (!provider.isInitialized)
                              const Column(
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "Initializing speech recognition...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            // Show recognized speech when listening
                            else if (provider.isListening)
                              Text(
                                provider.recognizedWord.isEmpty
                                    ? "Listening..."
                                    : provider.recognizedWord,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              )
                            else
                              // Show AI response when not listening
                              Text(
                                provider.lastResponse.isEmpty
                                    ? "Hold and speak to get started."
                                    : provider.lastResponse,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 22,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Mic button at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: MicButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MicButton extends StatefulWidget {
  const MicButton({super.key});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animation for pulsing effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onLongPress: provider.isInitialized && !provider.error 
              ? () => provider.startListening() 
              : null,
          onLongPressEnd: provider.isInitialized && !provider.error 
              ? (details) => provider.stopListening() 
              : null,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              // Base size
              double baseSize = 60;

              // Size logic: pulse when idle, grow smoothly when listening
              double size = provider.isListening
                  ? baseSize * _pulseAnimation.value + 40 // ~100
                  : baseSize * _pulseAnimation.value;

              // Glow effect when listening
              List<BoxShadow> shadow = provider.isListening
                  ? [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ]
                  : [];

              return AnimatedContainer(
                width: size,
                height: size,
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: provider.error 
                      ? Colors.grey 
                      : provider.isListening 
                          ? Colors.redAccent 
                          : provider.isInitialized 
                              ? Colors.black 
                              : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: shadow,
                ),
                child: Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: provider.isListening ? 40 : 28,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
