import 'dart:math' as math;
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceChatPage extends StatefulWidget {
  @override
  _VoiceChatPageState createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage> with SingleTickerProviderStateMixin {
  late ConversationClient _client;
  bool _isConnecting = false;
  bool _isConnected = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), 
    );

    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required String conversationId}) {
          setState(() => _isConnected = true);
          _waveController.repeat();
        },
        onDisconnect: (details) {
          setState(() => _isConnected = false);
          _waveController.stop();
        },
        onError: (message, [error]) => print("ElevenLabs Error: $message"),
      ),
    );
  }

  void _toggleConversation() async {
    if (_isConnected) {
      await _client.endSession();
      return;
    }

    setState(() => _isConnecting = true);

    
    var status = await Permission.microphone.status;
    
    
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      try {
        await _client.startSession(
          agentId: 'agent_5201kdb5jgdveapr59393xdsz07f',
        );
        await _client.setMicMuted(false);
      } catch (e) {
        print("ElevenLabs failed: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to start voice chat. Please try again.")),
        );
      }
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enable Microphone in Settings"),
          duration: Duration(seconds: 3),
        ),
      );
      await openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission is required")),
      );
    }

    setState(() => _isConnecting = false);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: BackgroundAmbientPainter(progress: _waveController.value),
                );
              },
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: _toggleConversation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: OrbPainter(
                          progress: _waveController.value,
                          isConnected: _isConnected,
                        ),
                        child: const SizedBox(width: 280, height: 280),
                      );
                    },
                  ),
                  if (_isConnecting)
                    const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.25,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isConnected ? "EmergeX is listening..." : "Ready to talk?",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isConnected ? "Go ahead, I'm all ears" : "Tap the orb to start Eric's voice",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundAmbientPainter extends CustomPainter {
  final double progress;
  BackgroundAmbientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    paint.color = Colors.blue.withOpacity(0.15);
    canvas.drawCircle(
      Offset(size.width * 0.2 + (math.sin(progress * 2 * math.pi) * 50), size.height * 0.3),
      150,
      paint,
    );

    paint.color = Colors.purple.withOpacity(0.1);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7 + (math.cos(progress * 2 * math.pi) * 50)),
      200,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OrbPainter extends CustomPainter {
  final double progress;
  final bool isConnected;

  OrbPainter({required this.progress, required this.isConnected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    if (!isConnected) {
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = [
          Colors.cyan.withOpacity(0.6),
          Colors.blueAccent.withOpacity(0.4),
          Colors.deepPurpleAccent.withOpacity(0.4),
          Colors.white.withOpacity(0.2),
        ][i]
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

      final double rotation = (progress * 2 * math.pi) + (i * math.pi / 2);
      final double xOffset = math.sin(rotation) * 20;
      final double yOffset = math.cos(rotation) * 20;

      canvas.drawCircle(
        Offset(center.dx + xOffset, center.dy + yOffset),
        radius + (math.sin(progress * 2 * math.pi + i) * 15),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(OrbPainter oldDelegate) => true;
}