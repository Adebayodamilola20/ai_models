import 'dart:ui';
import 'package:ai_models/shared/ProviderX/provider.dart';
import 'package:ai_models/views/pages/aivoicetts.dart';
import 'package:ai_models/views/pages/setting.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:provider/provider.dart';
import 'api_kwy.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'hugging.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  Map<String, bool> _isLikedMessages = {};
  Map<String, bool> _isDislikeMessage = {};
  final FocusNode _focusNode = FocusNode();
  final Map<String, AnimationController> _messageAnimations = {};
  final Map<String, List<AnimationController>> _iconAnimations = {};
  final List<String> _listSuggestion = [
    'Want to understand how EmergeX works  and what makes it different  from other AI tools?',
    'What  would really happen if the sun disappeared for just one second?',
    'How  does arttifical intelligence actually learn from data',
    'How much does a human brain actually weigh, and does it change as we grow older?',
  ];
  bool _isBlue = false;

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          print('onStatus: $val');
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          print('onError: $val');
          setState(() => _isListening = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${val.errorMsg}')));
        },
        debugLogging: true,
      );

      if (available) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(
          onResult: (val) {
            print('Speech result: ${val.recognizedWords}');
            setState(() {
              _textController.text = val.recognizedWords;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          },
          localeId: 'en_US',
          partialResults: true,
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(seconds: 60),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
    }
  }

  String? _currentChatId;

  void _startNewChat() {
    setState(() {
      _currentChatId = null;
      _messages.clear();
    });
  }

  void _loadChat(String chatId) async {
    setState(() {
      _currentChatId = chatId;
      _messages.clear();
    });

    try {
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

  Future<void> _ensureChatExists(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_currentChatId == null) {
      String smartTitle = "New Chat";
      try {
        final response = await http.post(
          Uri.parse('http://0.0.0.0:8080/generate_title'),
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
      _currentChatId = docRef.id;
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
        .doc(messageData['id']) // Use the same ID as the UI message
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

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        hasText = _textController.text.trim().isNotEmpty;
      });
    });
  }

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

      if (message is types.TextMessage &&
          message.text.isNotEmpty &&
          !isTyping) {
        for (int i = 0; i < controllers.length; i++) {
          Future.delayed(Duration(milliseconds: 100 * i), () {
            if (mounted) {
              controllers[i].forward();
            }
          });
        }
      }
    }
    return _iconAnimations[messageId]!;
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _messageAnimations.values) {
      controller.dispose();
    }
    for (var controllers in _iconAnimations.values) {
      for (var controller in controllers) {
        controller.dispose();
      }
    }
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

  void _handleSendPressed(types.PartialText message) async {
    final userMsg = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().toString(),
      text: message.text,
    );

    final File? imageToSend = selectedImage;
    setState(() {
      selectedImage = null;
      isTyping = true;
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

    final aiId = "${DateTime.now()}-ai";
    final aiPlaceholderMsg = types.TextMessage(
      author: _aiUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: aiId,
      text: "",
    );

    setState(() {
      _messages.insert(0, userMsg);
      if (imageMsg != null) {
        _messages.insert(0, imageMsg);
      }
      _messages.insert(0, aiPlaceholderMsg);
    });

    // 1. Ensure chat exists & Save User Message
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

    await _saveMessageToFirestore({
      'id': userMsg.id,
      'authorId': _user.id,
      'createdAt': userMsg.createdAt,
      'type': 'text',
      'text': userMsg.text,
    });

    try {
      String aiResponse = "";
      if (imageToSend != null) {
        aiResponse = await HuggingFaceService.analyzeImage(
          imageToSend,
          message.text,
        );
      } else {
        final history = _messages
            .whereType<types.TextMessage>()
            .where((m) => m.text.trim().isNotEmpty)
            .take(20) // Limit context window
            .map(
              (m) => {
                "role": m.author.id == _user.id ? "user" : "assistant",
                "text": m.text,
              },
            )
            .toList()
            .reversed
            .toList();

        String buffer = "";
        await for (final token in sendMessageStream(message.text, history)) {
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

        // Save final streamed response
        await _saveMessageToFirestore({
          'id': aiId,
          'authorId': _aiUser.id,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'type': 'text',
          'text': buffer,
        });

        setState(() => isTyping = false);

        final index = _messages.indexWhere((m) => m.id == aiId);
        if (index != -1) {
          final finalMessage = _messages[index];
          _triggerIconAnimations(aiId, finalMessage);
        }
        return;
      }

      // Save non-streamed response (image analysis)
      await _saveMessageToFirestore({
        'id': aiId,
        'authorId': _aiUser.id,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
        'text': aiResponse,
      });

      final index = _messages.indexWhere((m) => m.id == aiId);
      if (index != -1) {
        setState(() {
          _messages[index] = types.TextMessage(
            author: _aiUser,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: aiId,
            text: aiResponse,
          );
        });
        final finalMessage = _messages[index];
        _triggerIconAnimations(aiId, finalMessage);
      }
    } catch (e) {
      setState(() {
        _messages.insert(
          0,
          types.TextMessage(
            author: _aiUser,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: "${DateTime.now()}-err",
            text: "Error: $e",
          ),
        );
      });
    }

    setState(() {
      isTyping = false;
    });
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
        left: 20, // Slightly more margin for that iOS "floating" look
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
                        // Use a slightly dimmed icon to match the glass vibe
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
                            letterSpacing:
                                -0.3, // iOS uses tighter letter spacing
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

    overlay.insert(overlayEntry);
    animController.forward();

    Future.delayed(const Duration(milliseconds: 3400), () async {
      await animController.reverse();
      overlayEntry.remove();
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                focusNode: _focusNode,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
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
                        backgroundColor: Colors.white,
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
                                        icon: const Icon(Icons.close, size: 28),
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
                                        onTap: () {
                                          Navigator.pop(context);
                                          print('Files selected');
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
                                          style: TextStyle(color: Colors.grey),
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
                                          style: TextStyle(color: Colors.grey),
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
                    icon: const Icon(Icons.add, size: 24),
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
                    child: Text(
                      'DeepThink',
                      style: TextStyle(
                        color: _isBlue ? Colors.blue : Colors.white,
                        fontWeight: _isBlue ? FontWeight.w900 : FontWeight.w900,
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
                    icon: Icon(LucideIcons.send, size: 20),
                    color: Colors.blue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 23, 23, 23),
        title: const Text(
          "New Chat",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () {
                setState(() {
                  _currentChatId = null;
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.messageSquarePlus,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF171717),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EmergeX",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _currentChatId = null;
                          _messages.clear();
                        });
                        Navigator.pop(context);
                      },
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
                            Icon(
                              LucideIcons.plusCircle,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'New Chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () {
                        _showTopSnackbar(
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
                            Icon(
                              LucideIcons.layoutGrid,
                              color: Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Explore Apps',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                        style: TextStyle(color: Colors.white),
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

                  return ListView.builder(
                    padding: EdgeInsets.only(top: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(
                          data['title'] ?? 'Untitled Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onTap: () {
                          _loadChat(docs[index].id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(color: Colors.white12, height: 1),
            InkWell(
              onTap: () {
                Navigator.pop(context); // Close drawer first
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (BuildContext context) => const SettingsSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                color: const Color(0xFF1E1E1E),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blueAccent,
                        child: Text('P', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.settings, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Chat(
        messages: _messages,
        onSendPressed: _handleSendPressed,
        user: _user,
        showUserAvatars: true,
        emptyState: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      const Text(
                        'Hi,',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          color: Colors.white,
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
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Text(
                    'Where should we start?',
                    style: TextStyle(
                      color: Colors.white,
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
                                _textController.text = _listSuggestion[index];
                                _focusNode.requestFocus();
                              },
                              borderRadius: BorderRadius.circular(29),
                              child: Container(
                                width: 220,
                                height: 150,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 21,
                                  vertical: 25,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(29),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 0.3,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _listSuggestion[index],
                                    style: TextStyle(
                                      color: Colors.white,
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
        ),
        customBottomWidget: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                        if (firstLine.isNotEmpty && !firstLine.contains(' ')) {
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
                        child: OCLiquidGlassGroup(
                          settings: const OCLiquidGlassSettings(
                            refractStrength: 0.05,
                            blurRadiusPx: 2.0,
                            specStrength: 20.0,
                          ),
                          child: OCLiquidGlass(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  HighlightView(
                                    code,
                                    language: language,
                                    theme: customTheme,
                                    padding: const EdgeInsets.all(8),
                                    textStyle: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 22,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(text: code),
                                        ).then((_) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Copied to clipboard',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                            255,
                                            151,
                                            151,
                                            151,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Color.fromARGB(179, 0, 0, 0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          part,
                          style: TextStyle(
                            fontSize: 14,
                            color: message.author.id == _user.id
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      );
                    }
                  }).toList(),
                );
              }
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    color: message.author.id == _user.id
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              );
            },
        bubbleBuilder: _bubbleBuilder,
        theme: DefaultChatTheme(
          inputBackgroundColor: Colors.transparent,
          backgroundColor: const Color.fromARGB(255, 23, 23, 23),
          primaryColor: const Color(0xFFDEF2FF),
          secondaryColor: const Color.fromARGB(255, 23, 23, 23),
          inputTextColor: Colors.white,
          sentMessageBodyTextStyle: const TextStyle(
            color: const Color.fromARGB(255, 23, 23, 23),
            fontWeight: FontWeight.w500,
          ),
          receivedMessageBodyTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _bubbleBuilder(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) {
    final animController = _getOrCreateAnimation(message.id);
    final animation = CurvedAnimation(
      parent: animController,
      curve: Curves.easeOut,
    );

    final iconControllers =
        message.author.id != _user.id && message.text.isNotEmpty && !isTyping
        ? _getOrCreateIconAnimations(message.id, message)
        : <AnimationController>[];

    return Column(
      crossAxisAlignment: message.author.id == _user.id
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
                maxWidth: MediaQuery.of(context).size.width * 1.5,
              ),
              padding:  EdgeInsets.symmetric(
                horizontal: message.author.id == _user.id ? 16 : 0,
                vertical: 10),
              decoration: BoxDecoration(
                color: message.author.id == _user.id
                    ? const Color(0xFFDEF2FF)
                    : const Color.fromARGB(255, 23, 23, 23),
                borderRadius: BorderRadius.circular(16),
              ),
              child: child,
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
                _buildAnimatedIcon(iconControllers[2], LucideIcons.volumeX, () {
                  print('Regenerate message');
                }),

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
            icon: Icon(icon, size: 16),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
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
