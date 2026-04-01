import 'dart:ui';
import 'package:emerge_x/shared/ProviderX/provider.dart';
import 'package:emerge_x/views/pages/setting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/route_manager.dart';
import 'package:get/state_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_kwy.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/tts_service.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: 'user-id');
  final _aiUser = const types.User(id: 'ai-id', firstName: 'AI');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isLike = false;
  bool _isDisLike = false;

  File? selectedFile;
  Map<String, bool> _isLikedMessages = {};
  Map<String, bool> _isDislikeMessage = {};
  final FocusNode _focusNode = FocusNode();
  final Map<String, AnimationController> _messageAnimations = {};
  final Map<String, List<AnimationController>> _iconAnimations = {};
  OverlayEntry? _currentOverlay;
  bool _isGenerating = false;
  final List<String> _listSuggestion = [
    'Want to understand how EmergeX works  and what makes it different  from other AI tools?',
    'What  would really happen if the sun disappeared for just one second?',
    'How  does arttifical intelligence actually learn from data',
    'How much does a human brain actually weigh, and does it change as we grow older?',
  ];
  bool _isBlue = false;
  final ScrollController _scrollConroller = ScrollController();
  bool _showBacktoBottom = false;

  void _stopResponse() {
    setState(() {
      _isGenerating = false;
      isTyping = false;
    });
  }

  void _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            debugPrint('Speech Status: $val');
            // iOS often sends 'done' or 'notListening' when it stops
            if (val == 'done' || val == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (val) {
            debugPrint('Speech Error: ${val.errorMsg}');
            if (mounted) setState(() => _isListening = false);
            if (val.errorMsg != 'error_no_match' && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Microphone Error: ${val.errorMsg}')),
              );
            }
          },
          debugLogging: true,
        );

        if (available) {
          if (mounted) {
            setState(() => _isListening = true);
          }

          await _speech.listen(
            onResult: (val) {
              if (mounted) {
                setState(() {
                  _textController.text = val.recognizedWords;
                  _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textController.text.length),
                  );
                });
              }
            },
            localeId: 'en_US',
            listenMode:
                stt.ListenMode.dictation, // Better for continuous speech on iOS
            partialResults: true,
            pauseFor: const Duration(seconds: 20), // Increased for iOS
            listenFor: const Duration(minutes: 1),
            cancelOnError: true,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Speech recognition not available')),
            );
          }
        }
      } catch (e) {
        debugPrint('STT initialization error: $e');
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('STT stop error: $e');
      }
    }
  }

  String? _currentChatId;
  String _currentChatTitle = "New Chat";

  void _startNewChat() {
    setState(() {
      _currentChatId = null;
      _currentChatTitle = "New Chat";
      _messages.clear();
    });
  }

  void _loadChat(String chatId) async {
    setState(() {
      _currentChatId = chatId;
      _messages.clear();
    });

    try {
      // Get chat doc for title
      final chatDoc = await FirebaseFirestore.instance
          .collection('EmergeX')
          .doc(chatId)
          .get();
      if (chatDoc.exists) {
        setState(() {
          _currentChatTitle = chatDoc.data()?['title'] ?? "New Chat";
        });
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('EmergeX')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        final String type = data['type'] ?? 'text';
        final user = data['authorId'] == _user.id ? _user : _aiUser;

        if (type == 'image') {
          return types.ImageMessage(
            author: user,
            createdAt:
                data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
            id: doc.id,
            name: data['name'] ?? 'Image',
            size: data['size'] ?? 0,
            uri: data['uri'] ?? '',
            height: (data['height'] as num?)?.toDouble(),
            width: (data['width'] as num?)?.toDouble(),
          );
        } else {
          return types.TextMessage(
            author: user,
            createdAt:
                data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
            id: doc.id,
            text: data['text'] ?? '',
          );
        }
      }).toList();

      setState(() {
        _messages.addAll(loadedMessages);
      });
    } catch (e) {
      print("Error loading chat: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
    }
  }

  //MY fucking accent color saving

  Future<void> saveAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', color.value.toRadixString(16));
  }

  Future<Color> loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    String? colorHex = prefs.getString('accent_color');

    return colorHex != null
        ? Color(int.parse(colorHex, radix: 16))
        : Colors.blue;
  }

  Future<void> _ensureChatExists(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_currentChatId == null) {
      String smartTitle = "New Chat";
      try {
        final response = await http.post(
          Uri.parse('https://ai-models-94ei.onrender.com/generate_title'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"message": text}),
        );

        if (response.statusCode == 200) {
          smartTitle = jsonDecode(response.body)['title'];
        }
      } catch (e) {
        print("Title generation failed: $e");
      }

      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('EmergeX')
          .add({
            "title": smartTitle,
            "lastmessage": text,
            "userid": user.uid,
            "updateAt": FieldValue.serverTimestamp(),
          });
      setState(() {
        _currentChatId = docRef.id;
        _currentChatTitle = smartTitle;
      });
    } else {
      await FirebaseFirestore.instance
          .collection("EmergeX")
          .doc(_currentChatId)
          .update({
            "lastmessage": text,
            "updateAt": FieldValue.serverTimestamp(),
          });
    }
  }

  Future<void> _saveMessageToFirestore(Map<String, dynamic> messageData) async {
    if (_currentChatId == null) return;
    await FirebaseFirestore.instance
        .collection('EmergeX')
        .doc(_currentChatId)
        .collection('messages')
        .doc(messageData['id'])
        .set(messageData);
  }

  OCLiquidGlassSettings glassSettings = const OCLiquidGlassSettings(
    blendPx: 5,
    refractStrength: -0.2,
    distortFalloffPx: 45,
    distortExponent: 4,
    blurRadiusPx: 25,
    specAngle: 4,
    specStrength: 0.5,
    specPower: 120,
    specWidth: 10,
    lightbandOffsetPx: 10,
    lightbandWidthPx: 30,
    lightbandStrength: 0.9,
    lightbandColor: Colors.white,
  );

  bool isTyping = false;
  bool hasText = false;
  File? selectedImage;
  bool iconApp = false;

  AnimationController _getOrCreateAnimation(String messageId) {
    if (!_messageAnimations.containsKey(messageId)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      _messageAnimations[messageId] = controller;
      controller.forward();
    }
    return _messageAnimations[messageId]!;
  }

  List<AnimationController> _getOrCreateIconAnimations(
    String messageId,
    types.Message message,
  ) {
    if (!_iconAnimations.containsKey(messageId)) {
      List<AnimationController> controllers = [];
      for (int i = 0; i < 6; i++) {
        final controller = AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        );
        controllers.add(controller);
      }
      _iconAnimations[messageId] = controllers;
    }

    final controllers = _iconAnimations[messageId]!;
    if (message is types.TextMessage &&
        message.text.isNotEmpty &&
        !isTyping &&
        controllers[0].status == AnimationStatus.dismissed) {
      for (int i = 0; i < controllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) {
            controllers[i].forward();
          }
        });
      }
    }
    return controllers;
  }

  @override
  void initState() {
    super.initState();
    TtsService().initialize();
    _scrollConroller.addListener(() {
      if (_scrollConroller.hasClients) {
        if (_scrollConroller.offset > 50 && !_showBacktoBottom) {
          setState(() {
            _showBacktoBottom = true;
          });
        } else if (_scrollConroller.offset <= 50 && _showBacktoBottom) {
          setState(() {
            _showBacktoBottom = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollConroller.dispose();
    _textController.dispose();
    for (var controller in _messageAnimations.values) {
      controller.dispose();
    }
    for (var controllers in _iconAnimations.values) {
      for (var controller in controllers) {
        controller.dispose();
      }
    }
    _currentOverlay?.remove();
    _currentOverlay = null;
    super.dispose();
  }

  Future<void> _pickImageFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickfile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          File file = File(result.files.single.path!);
          String extension = result.files.single.extension?.toLowerCase() ?? '';
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            selectedImage = file;
          } else {
            selectedFile = file;
          }
        });
        print("File slected: ${result.files.single.path}");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  void _handleSendPressed(types.PartialText message) async {
    if (!_isGenerating) {
      _isGenerating = true;
    } else {
      return; // Already generating
    }
    // FocusScope.of(context).unfocus(); // Removed to allow keyboard to stay open
    final userMsg = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().toString(),
      text: message.text,
    );

    final File? imageToSend = selectedImage;
    final File? filetoSend = selectedFile;
    setState(() {
      selectedImage = null;
      selectedFile = null;
      isTyping = true;
      _isGenerating = true;
    });

    types.ImageMessage? imageMsg;
    if (imageToSend != null) {
      try {
        final bytes = await imageToSend.readAsBytes();
        final image = await decodeImageFromList(bytes);
        imageMsg = types.ImageMessage(
          author: _user,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          height: image.height.toDouble(),
          id: "${DateTime.now()}-img",
          name: imageToSend.path.split('/').last,
          size: imageToSend.lengthSync(),
          uri: imageToSend.path,
          width: image.width.toDouble(),
        );
      } catch (e) {
        print("Error decoding image: $e");
      }
    }

    types.FileMessage? fileMsg;
    if (filetoSend != null) {
      fileMsg = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: "${DateTime.now().millisecondsSinceEpoch}-file",
        name: filetoSend.path.split('/').last,
        size: filetoSend.lengthSync(),
        uri: filetoSend.path,
      );
    }

    final aiId = "${DateTime.now().millisecondsSinceEpoch}-ai";
    final aiPlaceholderMsg = types.TextMessage(
      author: _aiUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: aiId,
      text: "",
    );

    setState(() {
      _messages.insert(0, userMsg);
      if (imageMsg != null) _messages.insert(0, imageMsg);
      if (fileMsg != null) _messages.insert(0, fileMsg);
      _messages.insert(0, aiPlaceholderMsg);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollConroller.hasClients) {
        _scrollConroller.animateTo(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });

    // --- 2. SAVE TO FIRESTORE ---
    await _ensureChatExists(message.text);

    if (imageMsg != null) {
      await _saveMessageToFirestore({
        'id': imageMsg.id,
        'authorId': _user.id,
        'createdAt': imageMsg.createdAt,
        'type': 'image',
        'uri': imageMsg.uri,
        'name': imageMsg.name,
        'size': imageMsg.size,
        'height': imageMsg.height,
        'width': imageMsg.width,
      });
    }

    if (fileMsg != null) {
      await _saveMessageToFirestore({
        'id': fileMsg.id,
        'authorId': _user.id,
        'createdAt': fileMsg.createdAt,
        'type': 'file',
        'uri': fileMsg.uri,
        'name': fileMsg.name,
        'size': fileMsg.size,
      });
    }

    await _saveMessageToFirestore({
      'id': userMsg.id,
      'authorId': _user.id,
      'createdAt': userMsg.createdAt,
      'type': 'text',
      'text': userMsg.text,
    });

    try {
      String fileContentForAi = "";
      final textExtensions = [
        'json',
        'dart',
        'txt',
        'js',
        'yaml',
        'xml',
        'html',
        'md',
        'csv',
        'log',
        'css',
        'py',
      ];

      if (filetoSend != null) {
        try {
          final extension = filetoSend.path.split('.').last.toLowerCase();
          if (textExtensions.contains(extension)) {
            fileContentForAi = await filetoSend.readAsString();
          }
        } catch (e) {
          print("Error reading file: $e");
        }
      }

      final history = await Future.wait(
        _messages.take(20).map((m) async {
          String content = "";
          if (m is types.TextMessage) {
            content = m.text;
          } else if (m is types.FileMessage) {
            String historicFileContent = "";
            try {
              final fileObj = File(m.uri);
              if (await fileObj.exists()) {
                final ext = m.name.split('.').last.toLowerCase();
                if (textExtensions.contains(ext)) {
                  historicFileContent = await fileObj.readAsString();
                }
              }
            } catch (e) {
              print("Error reading historic file ${m.name}: $e");
            }

            if (historicFileContent.isNotEmpty) {
              content = "[File: ${m.name}]\nContent:\n$historicFileContent";
            } else {
              content = "[File: ${m.name}]";
            }
          } else if (m is types.ImageMessage) {
            content = "[Image: ${m.name}]";
          }

          return {
            "role": m.author.id == _user.id ? "user" : "assistant",
            "text": content,
          };
        }),
      );

      final historyList = history
          .where((m) => (m["text"] as String).isNotEmpty)
          .toList()
          .reversed
          .toList();

      String fullPrompt = message.text;
      if (fileContentForAi.isNotEmpty) {
        fullPrompt += "\n\nAnalyze this file content:\n$fileContentForAi";
      }

      String buffer = "";
      if (!_isGenerating) return; // Final check before start

      await for (final token in sendMessageStream(fullPrompt, historyList)) {
        if (!_isGenerating) {
          debugPrint("Generation stopped by user.");
          break;
        }

        // Increase delay slightly to give more breathe to the UI thread
        await Future.delayed(const Duration(milliseconds: 30));
        buffer += token;
        final index = _messages.indexWhere((m) => m.id == aiId);
        if (index != -1) {
          setState(() {
            _messages[index] = types.TextMessage(
              author: _aiUser,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: aiId,
              text: buffer,
            );
          });
        }
      }

      await _saveMessageToFirestore({
        'id': aiId,
        'authorId': _aiUser.id,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
        'text': buffer,
      });

      setState(() => isTyping = false);
      if (_isGenerating) {
        _updateSuggestions(buffer);
      }

      final index = _messages.indexWhere((m) => m.id == aiId);
      if (index != -1) {
        _triggerIconAnimations(aiId, _messages[index]);
      }
    } catch (e) {
      print("AI Error: $e");
      if (mounted) setState(() => isTyping = false);
    } finally {
      if (mounted) {
        setState(() {
          isTyping = false;
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _updateSuggestions(String lastAiResponse) async {
    if (!_isGenerating) return; // Guard
    final prompt =
        "Based on the following AI response, generate 3 short, relevant, and engaging follow-up questions for the user to ask next. Return ONLY a JSON list of strings, exactly in this format: [\"Question 1\", \"Question 2\", \"Question 3\"]. Do not include any other text or explanation. AI Response: $lastAiResponse";

    try {
      String fullResponse = "";
      await for (final token in sendMessageStream(prompt, [])) {
        if (!_isGenerating) {
          debugPrint("Suggestion generation stopped by user.");
          break;
        }
        fullResponse += token;
      }

      // Basic cleanup of JSON in case the AI wraps it in markdown blocks
      if (fullResponse.contains("[") && fullResponse.contains("]")) {
        final start = fullResponse.indexOf("[");
        final end = fullResponse.lastIndexOf("]") + 1;
        final jsonPart = fullResponse.substring(start, end);

        final List<dynamic> newSuggestions = jsonDecode(jsonPart);
        if (newSuggestions.isNotEmpty) {
          setState(() {
            _listSuggestion.clear();
            _listSuggestion.addAll(newSuggestions.map((e) => e.toString()));
          });
        }
      }
    } catch (e) {
      print("Error updating suggestions: $e");
    }
  }

  void _showTopSnackbar(String message, {IconData? icon}) {
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;
    late AnimationController animController;

    animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animController, curve: Curves.easeOut));

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: SlideTransition(
          position: slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 0.5, // Thin, sharp borders look more premium
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: -5,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: Colors.white.withOpacity(0.9),
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _currentOverlay?.remove();
    _currentOverlay = overlayEntry;
    overlay.insert(overlayEntry);
    animController.forward();

    Future.delayed(const Duration(milliseconds: 3400), () async {
      await animController.reverse();
      if (_currentOverlay == overlayEntry) {
        overlayEntry.remove();
        _currentOverlay = null;
      }
      animController.dispose();
    });
  }

  void _triggerIconAnimations(String messageId, types.Message message) {
    final controllers = _getOrCreateIconAnimations(messageId, message);
    for (int i = 0; i < controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 * i), () {
        if (mounted) {
          controllers[i].forward();
        }
      });
    }
  }

  Widget _buildCustomInput() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeybaordOpen = keyboardHeight > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selectedImage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    selectedImage!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedImage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (selectedFile != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedFile!.path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        selectedFile = null;
                      });
                    },
                    icon: Icon(Icons.close, color: Colors.red, size: 20),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Container(
            margin: EdgeInsets.only(
              bottom: isKeybaordOpen ? 10 : 0,
              left: isKeybaordOpen ? 10 : 0,
              right: isKeybaordOpen ? 10 : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
                bottomLeft: isKeybaordOpen ? Radius.circular(25) : Radius.zero,
                bottomRight: isKeybaordOpen ? Radius.circular(25) : Radius.zero,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  minLines: 1,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: 16,
                  ),
                  enableInteractiveSelection: true,
                  contextMenuBuilder: (context, editableTextState) {
                    return AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    );
                  },
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Chat with EmergeX',
                    hintStyle: TextStyle(
                      color:
                          (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black)
                              .withOpacity(0.5),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      // FocusScope.of(context).unfocus(); // Removed to allow keyboard to stay open
                      _handleSendPressed(types.PartialText(text: text));
                      _textController.clear();
                      setState(() {
                        selectedImage = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(25),
                            ),
                          ),
                          builder: (context) {
                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          icon: const Icon(
                                            Icons.close,
                                            size: 28,
                                          ),
                                        ),
                                        const Expanded(
                                          child: Center(
                                            child: Text(
                                              'Add to Chat',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 48),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildOptionCard(
                                          icon: Icons.camera_alt_outlined,
                                          label: 'Camera',
                                          onTap: () async {
                                            Navigator.pop(context);
                                            await _pickImageFromCamera();
                                          },
                                        ),
                                        _buildOptionCard(
                                          icon: Icons.photo_outlined,
                                          label: 'Photos',
                                          onTap: () async {
                                            Navigator.pop(context);
                                            await _pickImageFromGallery();
                                          },
                                        ),
                                        _buildOptionCard(
                                          icon: Icons.file_upload_outlined,
                                          label: 'Files',
                                          onTap: () async {
                                            Navigator.pop(context);
                                            await _pickfile();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.language,
                                        size: 28,
                                      ),
                                      title: const Text(
                                        'Web search',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      trailing: Switch(
                                        value: true,
                                        onChanged: (value) {},
                                      ),
                                    ),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.folder_outlined,
                                        size: 28,
                                      ),
                                      title: const Text(
                                        'Add to project',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'None',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                      onTap: () {},
                                    ),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.edit_outlined,
                                        size: 28,
                                      ),
                                      title: const Text(
                                        'Choose style',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Normal',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      icon: Icon(
                        Icons.add,
                        size: 24,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                      color: Colors.white70,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isBlue = !_isBlue;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(55, 29),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 27,
                          vertical: 13,
                        ),
                        backgroundColor: _isBlue
                            ? const Color.fromARGB(
                                255,
                                76,
                                174,
                                254,
                              ).withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                      ).copyWith(elevation: WidgetStateProperty.all(0)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'DeepThink',
                          style: TextStyle(
                            color: _isBlue
                                ? Colors.blue
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        _listen();
                      },
                      icon: Icon(
                        _isListening ? Icons.stop : LucideIcons.mic,
                        color: _isListening ? Colors.red : Colors.blue,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 7),
                    IconButton(
                      onPressed: () {
                        if (_isGenerating) {
                          _stopResponse();
                          return;
                        }
                        if (_textController.text.trim().isNotEmpty) {
                          _handleSendPressed(
                            types.PartialText(text: _textController.text),
                          );
                          _textController.clear();
                          setState(() {
                            selectedImage = null;
                          });
                        }
                      },
                      icon: Icon(
                        _isGenerating
                            ? Icons.stop_circle_outlined
                            : LucideIcons.send,
                        size: 20,
                      ),
                      color: _isGenerating ? Colors.red : Colors.blue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _showBacktoBottom
          ? Padding(
              padding: EdgeInsets.only(
                bottom: 80,
              ), // Adjust to be above text field if needed, dependent on layout
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.blue,
                onPressed: _scrollToBottom,
                child: Icon(Icons.arrow_downward, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          _currentChatTitle,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () {
                _startNewChat();
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                child: Icon(
                  LucideIcons.plus,
                  size: 20,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),
          ),
        ],
        leading: Builder(
          builder: (context) {
            return InkWell(
              onTap: () {
                Scaffold.of(context).openDrawer();
                FocusScope.of(context).unfocus();
              },
              child: Image(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                image: AssetImage('assets/images/text-align-start.png'),
              ),
            );
          },
        ),
      ),
      drawer: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Drawer(
          backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
          width: 350,
          child: StaggeredDrawerContent(
            currentChatId: _currentChatId,
            onNewChat: () {
              _startNewChat();
              Navigator.pop(context);
            },
            onLoadChat: (id) {
              _loadChat(id);
              Navigator.pop(context);
            },
            onShowSettings: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (BuildContext context) => const SettingsSheet(),
              );
            },
            onShowSnackbar: (msg, {icon}) => _showTopSnackbar(msg, icon: icon),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Consumer<Userprovider>(
          builder: (context, provider, child) {
            return Chat(
              theme: DefaultChatTheme(
                inputBackgroundColor: Colors.transparent,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                primaryColor: provider.accentColor,
                secondaryColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                inputTextColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                sentMessageBodyTextStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                receivedMessageBodyTextStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
                messageInsetsHorizontal: 0,
                messageInsetsVertical: 4,
              ),
              messageWidthRatio: 1.0,
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user,
              onMessageTap: (context, message) {
                if (message is types.FileMessage) {
                  print("Opening file: ${message.uri}");
                }
              },
              showUserAvatars: false,
              emptyState: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18.0,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Hi,',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Consumer<Userprovider>(
                              builder: (context, provider, child) {
                                final name = provider.firstname.isEmpty
                                    ? 'User'
                                    : provider.firstname;
                                return Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Where should we start?',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          height: 160,
                          width: MediaQuery.of(context).size.width,
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(scrollbars: false),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _listSuggestion.length,
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: InkWell(
                                    onTap: () {
                                      _textController.text =
                                          _listSuggestion[index];
                                      _focusNode.requestFocus();
                                    },
                                    borderRadius: BorderRadius.circular(29),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 220,
                                        minHeight: 150,
                                      ),
                                      width: 220,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 21,
                                        vertical: 25,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.black.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(29),
                                        border: Border.all(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white.withOpacity(0.25)
                                              : Colors.black.withOpacity(0.1),
                                          width: 0.3,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _listSuggestion[index],
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.start,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: isTyping ? [_aiUser] : [],
                customTypingIndicator: isTyping
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "Ai is typing ...",
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color.fromARGB(137, 255, 255, 255)
                                : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
              ),
              customBottomWidget: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: _buildCustomInput(),
                  ),
                ),
              ),
              textMessageBuilder:
                  (
                    types.TextMessage message, {
                    required int messageWidth,
                    required bool showName,
                  }) {
                    final text = message.text;
                    if (text.contains("```")) {
                      final parts = text.split("```");
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: parts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final part = entry.value;
                          if (index % 2 != 0) {
                            final lines = part.split('\n');
                            String language = 'plaintext';
                            String code = part;
                            if (lines.isNotEmpty) {
                              final firstLine = lines.first.trim();
                              if (firstLine.isNotEmpty &&
                                  !firstLine.contains(' ')) {
                                language = firstLine;
                                code = lines.skip(1).join('\n');
                              }
                            }

                            var customTheme = Map<String, TextStyle>.from(
                              atomOneDarkTheme,
                            );
                            customTheme['root'] = TextStyle(
                              backgroundColor: Colors.transparent,
                              color: atomOneDarkTheme['root']?.color,
                            );

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E1E1E,
                                  ), // Dark container background
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: OCLiquidGlassGroup(
                                  settings: const OCLiquidGlassSettings(
                                    refractStrength: 0.02,
                                    blurRadiusPx: 1.0,
                                    specStrength: 5.0,
                                  ),
                                  child: OCLiquidGlass(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: messageWidth.toDouble() - 40,
                                      ),
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 16,
                                                  ),
                                              child: HighlightView(
                                                code,
                                                language: language,
                                                theme: customTheme,
                                                textStyle: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize:
                                                      14, // Slightly smaller for better fit
                                                  height: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  Clipboard.setData(
                                                    ClipboardData(text: code),
                                                  ).then((_) {
                                                    _showTopSnackbar(
                                                      "Copied to clipboard",
                                                      icon: Icons.check_circle,
                                                    );
                                                  });
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.copy,
                                                    size: 16,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (language != 'plaintext')
                                            Positioned(
                                              top: 8,
                                              left: 12,
                                              child: Text(
                                                language.toUpperCase(),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.3),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              constraints: BoxConstraints(
                                maxWidth: messageWidth.toDouble() - 50,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: AnimatedStreamingText(
                                text: text.replaceAll(
                                  '**',
                                  '',
                                ), // Simply remove the ** markers
                                style: TextStyle(
                                  fontSize: 17,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            );
                          }
                        }).toList(),
                      );
                    }
                    return Container(
                      constraints: BoxConstraints(
                        maxWidth: messageWidth.toDouble() - 50,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: AnimatedStreamingText(
                        text: text.replaceAll('**', ''),
                        style: TextStyle(
                          fontSize: 17,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    );
                  },
              bubbleBuilder: _bubbleBuilder,
              fileMessageBuilder: (message, {required messageWidth}) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  height: 60,
                  constraints: BoxConstraints(
                    maxWidth: messageWidth.toDouble(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insert_drive_file,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${(message.size / 1024).toStringAsFixed(1)} KB",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _bubbleBuilder(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) {
    final accentColor = context.watch<Userprovider>().accentColor;
    final isMe = message.author.id == _user.id;

    final animController = _getOrCreateAnimation(message.id);
    final animation = CurvedAnimation(
      parent: animController,
      curve: Curves.easeOut,
    );

    final iconControllers =
        message.author.id != _user.id && message.text.isNotEmpty
        ? _getOrCreateIconAnimations(message.id, message)
        : <AnimationController>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isMe
                        ? constraints.maxWidth *
                              0.8 // User messages stay at 80%
                        : constraints.maxWidth - 45,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMe ? 16 : 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (accentColor == Colors.transparent
                              ? (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05))
                              : accentColor)
                        : Colors.transparent, // No background for AI
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: isMe
                        ? Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0,
                          )
                        : null,
                    boxShadow: [
                      if (isMe && accentColor != Colors.transparent)
                        BoxShadow(
                          color: accentColor.withOpacity(
                            0.2,
                          ), // Glow matches accent
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  // No background for AI
                  child: isMe
                      ? GestureDetector(
                          onLongPressStart: (details) {
                            final position = details.globalPosition;
                            showMenu(
                              context: context,
                              position: RelativeRect.fromLTRB(
                                position.dy,
                                position.dx,
                                0,
                                0,
                              ),
                              items: [
                                PopupMenuItem(
                                  value: 'Copy',
                                  child: Text('Copy'),
                                ),
                                PopupMenuItem(
                                  value: 'paste',
                                  child: Text('paste'),
                                ),
                              ],
                            ).then((value) {
                              if (value == 'copy') {
                                print("Copy clicked");
                              } else if (value == 'paste') {
                                print("Paste clicked");
                              } else if (value == 'delete') {
                                print("Delete clicked");
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SelectionArea(child: child),
                          ),
                        )
                      : Container(
                          width:
                              constraints.maxWidth -
                              45, // Force width constraint
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SelectionArea(child: child),
                        ),
                ),
              ),
            ),
            if (message.author.id != _user.id &&
                message.text.isNotEmpty &&
                iconControllers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedIcon(iconControllers[0], Icons.copy, () {
                      _showTopSnackbar(
                        "Copied to clipboard",
                        icon: Icons.check_circle,
                      );
                    }),

                    const SizedBox(width: 2),
                    _buildAnimatedIcon(
                      iconControllers[2],
                      LucideIcons.volumeX,
                      () {
                        print('Regenerate message');
                      },
                    ),

                    InkWell(
                      onTap: () {},
                      child: _buildAnimatedIcon(
                        iconControllers[3],
                        (_isLikedMessages[message.id] ?? false)
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        () {
                          setState(() {
                            bool currentlyLiked =
                                _isLikedMessages[message.id] ?? false;
                            _isLikedMessages[message.id] = !currentlyLiked;

                            if (_isLikedMessages[message.id] == true) {
                              _isDislikeMessage[message.id] = false;
                              _showTopSnackbar(
                                icon: Icons.close,
                                "Thank you for your feedback",
                              );
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: () {},
                      child: _buildAnimatedIcon(
                        iconControllers[3],
                        (_isDislikeMessage[message.id] ?? false)
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
                        () {
                          setState(() {
                            bool currentlyDisliked =
                                _isDislikeMessage[message.id] ?? false;
                            _isDislikeMessage[message.id] = !currentlyDisliked;

                            if (_isLikedMessages[message.id] == true) {
                              _isLikedMessages[message.id] = false;
                              _showTopSnackbar(
                                icon: Icons.close,
                                "Thank you for your feedback",
                              );
                            }
                          });
                        },
                      ),
                    ),

                    _buildAnimatedIcon(
                      iconControllers[5],
                      Icons.more_horiz_outlined,
                      () {
                        print('More options');
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedIcon(
    AnimationController controller,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: SizedBox(
          width: 28,
          height: 24,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    _scrollConroller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

Widget _buildOptionCard({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}

class StaggeredDrawerContent extends StatefulWidget {
  final String? currentChatId;
  final VoidCallback onNewChat;
  final Function(String) onLoadChat;
  final VoidCallback onShowSettings;
  final Function(String, {IconData? icon}) onShowSnackbar;

  const StaggeredDrawerContent({
    super.key,
    this.currentChatId,
    required this.onNewChat,
    required this.onLoadChat,
    required this.onShowSettings,
    required this.onShowSnackbar,
  });

  @override
  State<StaggeredDrawerContent> createState() => _StaggeredDrawerContentState();
}

class _StaggeredDrawerContentState extends State<StaggeredDrawerContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    await _controller.reverse();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _controller.reverse();
        if (mounted) Navigator.of(context).pop();
      },
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _StaggeredItem(
              index: 0,
              animation: _controller,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Text(
                      "EmergeX",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _StaggeredItem(
            index: 1,
            animation: _controller,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: widget.onNewChat,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.plusCircle,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'New Chat',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          _StaggeredItem(
            index: 2,
            animation: _controller,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  widget.onShowSnackbar(
                    "Apps coming soon!",
                    icon: LucideIcons.layers,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.layoutGrid,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Explore Apps',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('EmergeX')
                  .where(
                    'userid',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('updateAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error: ${snapshot.error}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No chats found in DB",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isSelected = docs[index].id == widget.currentChatId;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 600),
                        child: SlideAnimation(
                          horizontalOffset: -100.0,
                          child: FadeInAnimation(
                            child: _StaggeredItem(
                              index: index + 3,
                              animation: _controller,
                              isExitOnly: true, // Only handle exit slide-up
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: isSelected
                                        ? ImageFilter.blur(
                                            sigmaX: 10,
                                            sigmaY: 10,
                                          )
                                        : ImageFilter.blur(
                                            sigmaX: 0,
                                            sigmaY: 0,
                                          ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white.withOpacity(
                                                      0.1,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.05,
                                                    ))
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white.withOpacity(
                                                        0.2,
                                                      )
                                                    : Colors.black.withOpacity(
                                                        0.1,
                                                      ),
                                                width: 0.5,
                                              )
                                            : null,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          data['title'] ?? 'Untitled Chat',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        onTap: () =>
                                            widget.onLoadChat(docs[index].id),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.white12, height: 1),
          _StaggeredItem(
            index: 10, // Far down the line
            animation: _controller,
            child: InkWell(
              onTap: widget.onShowSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromARGB(255, 0, 0, 0)
                    : Colors.white,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Consumer<Userprovider>(
                        builder: (context, provider, child) {
                          final firstname = provider.firstname.isNotEmpty
                              ? provider.firstname
                              : "S";
                          final lastname = provider.lastname.isNotEmpty
                              ? provider.lastname
                              : "D";
                          final fullName = "$firstname $lastname";
                          final initial =
                              (firstname.isNotEmpty
                                  ? firstname.substring(0, 1)
                                  : "") +
                              (lastname.isNotEmpty
                                  ? lastname.substring(0, 1)
                                  : "");
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: const Color(0xFF4285F4),
                                child: Text(
                                  initial.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 19,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      const Spacer(),
                      Icon(
                        Icons.settings,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
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

class _StaggeredItem extends StatelessWidget {
  final int index;
  final Animation<double> animation;
  final Widget child;
  final bool isExitOnly;

  const _StaggeredItem({
    required this.index,
    required this.animation,
    required this.child,
    this.isExitOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final isReversing = animation.status == AnimationStatus.reverse;

        if (isExitOnly && !isReversing) return child!;

        final start = (0.08 * index).clamp(0.0, 0.8);
        final end = (start + 0.3).clamp(0.0, 1.0);

        final staggerAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(start, end, curve: Curves.easeOutQuart),
        );

        final tween = isReversing
            ? Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(-0.35, 0), end: Offset.zero);

        return FadeTransition(
          opacity: staggerAnimation,
          child: SlideTransition(
            position: tween.animate(staggerAnimation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AnimatedStreamingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const AnimatedStreamingText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<AnimatedStreamingText> createState() => _AnimatedStreamingTextState();
}

class _AnimatedStreamingTextState extends State<AnimatedStreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _visibleText = '';
  String _newTextToAnimate = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(
        milliseconds: 300,
      ), // Slightly slower for smoothness
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _visibleText = widget.text;
    _controller.value = 1.0; // Initial text is fully visible
  }

  @override
  void didUpdateWidget(AnimatedStreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text) {
      // If widget.text grew, animate the difference
      if (widget.text.startsWith(_visibleText) &&
          widget.text.length > _visibleText.length) {
        setState(() {
          // If we were already animating some text, commit it to visible text
          if (_newTextToAnimate.isNotEmpty) {
            _visibleText += _newTextToAnimate;
          }
          _newTextToAnimate = widget.text.substring(_visibleText.length);
        });
        _controller.reset();
        _controller.forward();
      } else if (widget.text.length < _visibleText.length ||
          !widget.text.startsWith(_visibleText)) {
        // Text was reset or changed completely (e.g. new message)
        setState(() {
          _visibleText = widget.text;
          _newTextToAnimate = '';
        });
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(text: _visibleText, style: widget.style),
          if (_newTextToAnimate.isNotEmpty)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(_newTextToAnimate, style: widget.style),
              ),
            ),
        ],
      ),
    );
  }
}
