import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VoiceChatScreen extends StatefulWidget {
  @override
  _VoiceChatScreenState createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  static const String _openRouterApiKey =
      "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";
  static const String _modelId = "mistralai/mistral-7b-instruct";
  static const String _apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  late FlutterTts tts;
  String botReply = "Tap the microphone icon to hear the AI speak.";
  bool isSpeaking = false;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    tts = FlutterTts();
    _initTts();

    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
      lowerBound: 0.9,
      upperBound: 1.1,
    );
    // The animation starts and stops only when isSpeaking changes.
  }

  void _initTts() {
    // Handler for when the AI finishes speaking
    tts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
        botReply = "Tap the microphone icon to hear the AI speak.";
      });
      _controller.stop();
    });

    _setTtsProperties();
  }

  Future<void> _setTtsProperties() async {
    await tts.setLanguage("en-US");

    await tts.setPitch(1.0);

    await tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _controller.dispose();
    tts.stop();
    super.dispose();
  }

  // Toggles the speaking state (Start/Stop)
  Future<void> _toggleSpeaking() async {
    // 1. STOP: If currently speaking, stop the speech immediately
    if (isSpeaking) {
      await tts.stop();
      setState(() {
        isSpeaking = false;
      });
      _controller.stop();
      return;
    }

    // 2. START: If not speaking, initiate the AI call
    setState(() {
      isSpeaking = true;
      botReply = "Thinking...";
    });
    _controller.repeat(reverse: true);

    // The fixed prompt used since microphone input is disabled
    final fixedPrompt =
        "Tell me a fun fact about Flutter development, and keep it brief.";

    await sendToAI(fixedPrompt);
  }

  // >>> UPDATED FUNCTION TO USE OPENROUTER API <<<
  Future<void> sendToAI(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://your-app-url.com',
              'X-Title': 'CogiChat App',
            },
            body: jsonEncode({
              'model': _modelId,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.7,
              'max_tokens': 150,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Correctly parse the response structure (OpenAI compatible)
        final aiResponseText =
            data['choices'][0]['message']['content'] as String? ??
            "I'm sorry, I received an empty response.";

        setState(() {
          botReply = aiResponseText;
        });

        await tts.speak(aiResponseText);
      } else {
        // Handle API errors
        print(
          "OpenRouter API Error: Status ${response.statusCode}, Body: ${response.body}",
        );
        setState(() {
          isSpeaking = false;
          botReply = "API connection failed. Status: ${response.statusCode}";
        });
        _controller.stop();
      }
    } catch (e) {
      print("Network/API Exception: $e");
      setState(() {
        isSpeaking = false;
        botReply = "AI connection failed. Check your API key or network.";
      });
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSpeaking) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("CogiChat Voice Assistant"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 40),

            GestureDetector(
              onTap: _toggleSpeaking, // Simple tap to start/stop
              child: ScaleTransition(
                // Animation is only active when isSpeaking is true
                scale: isSpeaking
                    ? _controller
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Use a more vibrant color when active
                    color: isSpeaking ? Colors.blueAccent : Colors.grey[400],
                    boxShadow: [
                      BoxShadow(
                        // Create the 'glowing' effect when speaking
                        color: isSpeaking
                            ? Colors.blueAccent.withOpacity(0.5)
                            : Colors.transparent,
                        blurRadius: 20,
                        spreadRadius: isSpeaking ? 8 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    // Icon changes based on whether the AI is talking
                    isSpeaking ? LucideIcons.volume2 : LucideIcons.mic,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),

            SizedBox(height: 40),

            Text(
              isSpeaking
                  ? "AI is Speaking..."
                  : "Tap the icon to start the conversation.",
              style: TextStyle(
                fontSize: 16,
                color: isSpeaking ? Colors.blue[800] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 50),

            Expanded(
              child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    botReply,
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
