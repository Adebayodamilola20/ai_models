import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../pages/api_kwy.dart';
import '../pages/hugging.dart';

class ChatViewModel extends ChangeNotifier {
  final List<types.Message> _messages = [];
  final types.User _user = const types.User(id: 'user-id');
  final types.User _aiUser = const types.User(id: 'ai-id', firstName: 'AI');
  
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<types.Message> get messages => _messages;
  types.User get user => _user;
  types.User get aiUser => _aiUser;

  bool _isListening = false;
  bool get isListening => _isListening;
  
  bool _isPickerActive = false;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _isBlue = false;
  bool get isBlue => _isBlue;

  bool _showBackToBottom = false;
  bool get showBackToBottom => _showBackToBottom;

  String? _currentChatId;
  String? get currentChatId => _currentChatId;

  String _currentChatTitle = "New Chat";
  String get currentChatTitle => _currentChatTitle;

  File? selectedImage;
  File? selectedFile;

  final Map<String, bool> _isLikedMessages = {};
  final Map<String, bool> _isDislikeMessage = {};

  bool isLiked(String messageId) => _isLikedMessages[messageId] ?? false;
  bool isDisliked(String messageId) => _isDislikeMessage[messageId] ?? false;

  void toggleLike(String messageId) {
    _isLikedMessages[messageId] = !isLiked(messageId);
    if (_isLikedMessages[messageId] == true) {
      _isDislikeMessage[messageId] = false;
    }
    notifyListeners();
  }

  void toggleDislike(String messageId) {
    _isDislikeMessage[messageId] = !isDisliked(messageId);
    if (_isDislikeMessage[messageId] == true) {
      _isLikedMessages[messageId] = false;
    }
    notifyListeners();
  }

  final List<String> _listSuggestion = [
    'Want to understand how EmergeX works  and what makes it different  from other AI tools?',
    'What  would really happen if the sun disappeared for just one second?',
    'How  does arttifical intelligence actually learn from data',
    'How much does a human brain actually weigh, and does it change as we grow older?',
  ];
  List<String> get listSuggestion => _listSuggestion;

  ChatViewModel() {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (scrollController.hasClients) {
      if (scrollController.offset > 50 && !_showBackToBottom) {
        _showBackToBottom = true;
        notifyListeners();
      } else if (scrollController.offset <= 50 && _showBackToBottom) {
        _showBackToBottom = false;
        notifyListeners();
      }
    }
  }

  void toggleDeepThink() {
    _isBlue = !_isBlue;
    notifyListeners();
  }

  void stopResponse() {
    _isGenerating = false;
    _isTyping = false;
    notifyListeners();
  }

  void startNewChat() {
    _currentChatId = null;
    _currentChatTitle = "New Chat";
    _messages.clear();
    notifyListeners();
  }

  Future<void> loadChat(String chatId) async {
    _currentChatId = chatId;
    _messages.clear();
    notifyListeners();

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('EmergeX')
          .doc(chatId)
          .get();
      if (chatDoc.exists) {
        _currentChatTitle = chatDoc.data()?['title'] ?? "New Chat";
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
            createdAt: data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
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
            createdAt: data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
            id: doc.id,
            text: data['text'] ?? '',
          );
        }
      }).toList();

      _messages.addAll(loadedMessages);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading chat: $e");
    }
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
        debugPrint("Title generation failed: $e");
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
      _currentChatTitle = smartTitle;
      notifyListeners();
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

  Future<void> handleSendPressed(types.PartialText message) async {
    // focusNode.unfocus(); // Removed to allow keyboard to stay open
    final userMsg = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().toString(),
      text: message.text,
    );

    final File? imageToSend = selectedImage;
    final File? filetoSend = selectedFile;
    
    selectedImage = null;
    selectedFile = null;
    _isTyping = true;
    _isGenerating = true;
    notifyListeners();

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
        debugPrint("Error decoding image: $e");
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

    _messages.insert(0, userMsg);
    if (imageMsg != null) _messages.insert(0, imageMsg);
    if (fileMsg != null) _messages.insert(0, fileMsg);
    _messages.insert(0, aiPlaceholderMsg);
    
    // Auto scroll to latest
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    notifyListeners();

    await _ensureChatExists(message.text);

    await _ensureChatExists(message.text);

    // --- Image Reading (Captioning) ---
    if (imageMsg != null && imageToSend != null) {
      final description = await HuggingFaceService.analyzeImage(imageToSend);
      final index = _messages.indexWhere((m) => m.id == aiId);
      if (index != -1) {
        _messages[index] = types.TextMessage(
          author: _aiUser,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: aiId,
          text: description,
        );
        notifyListeners();
      }
      await _saveMessageToFirestore({
        'id': aiId,
        'authorId': _aiUser.id,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
        'text': description,
      });

      // Also save the user image message
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

      _isTyping = false;
      _isGenerating = false;
      notifyListeners();
      return; // Stop here if we're just explaining an image
    }

    // --- Image Generation ---
    final String lowerText = message.text.toLowerCase();
    final isGenRequest = lowerText.contains("generate") || 
                        lowerText.contains("create image") ||
                        lowerText.contains("show me a picture") ||
                        lowerText.contains("draw");
    
    if (isGenRequest) {
      final generatedFile = await HuggingFaceService.generateImage(message.text);
      if (generatedFile != null) {
        final bytes = await generatedFile.readAsBytes();
        final image = await decodeImageFromList(bytes);
        final aiImageMsg = types.ImageMessage(
          author: _aiUser,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          height: image.height.toDouble(),
          id: "${DateTime.now().millisecondsSinceEpoch}-ai-gen",
          name: "generated.png",
          size: generatedFile.lengthSync(),
          uri: generatedFile.path,
          width: image.width.toDouble(),
        );

        // Replace placeholder with generated image
        final index = _messages.indexWhere((m) => m.id == aiId);
        if (index != -1) {
          _messages[index] = aiImageMsg;
          notifyListeners();
        }

        await _saveMessageToFirestore({
          'id': aiImageMsg.id,
          'authorId': _aiUser.id,
          'createdAt': aiImageMsg.createdAt,
          'type': 'image',
          'uri': aiImageMsg.uri,
          'name': aiImageMsg.name,
          'size': aiImageMsg.size,
          'height': aiImageMsg.height,
          'width': aiImageMsg.width,
        });

        // Also save the user text message that triggered this
        await _saveMessageToFirestore({
          'id': userMsg.id,
          'authorId': _user.id,
          'createdAt': userMsg.createdAt,
          'type': 'text',
          'text': userMsg.text,
        });
      } else {
        final index = _messages.indexWhere((m) => m.id == aiId);
        if (index != -1) {
          _messages[index] = types.TextMessage(
            author: _aiUser,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: aiId,
            text: "Failed to generate image. Please try again later.",
          );
          notifyListeners();
        }
      }
      _isTyping = false;
      _isGenerating = false;
      notifyListeners();
      return;
    }

    // Standard saving for text messages that aren't image requests
    await _saveMessageToFirestore({
      'id': userMsg.id,
      'authorId': _user.id,
      'createdAt': userMsg.createdAt,
      'type': 'text',
      'text': userMsg.text,
    });

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

    try {
      String fileContentForAi = "";
      final textExtensions = ['json', 'dart', 'txt', 'js', 'yaml', 'xml', 'html', 'md', 'csv', 'log', 'css', 'py'];

      if (filetoSend != null) {
        final extension = filetoSend.path.split('.').last.toLowerCase();
        if (textExtensions.contains(extension)) {
          fileContentForAi = await filetoSend.readAsString();
        }
      }

      final history = await Future.wait(
        _messages.take(20).map((m) async {
          String content = "";
          if (m is types.TextMessage) {
            content = m.text;
          } else if (m is types.FileMessage) {
              final fileObj = File(m.uri);
              if (await fileObj.exists()) {
                final ext = m.name.split('.').last.toLowerCase();
                if (textExtensions.contains(ext)) {
                  content = "[File: ${m.name}]\nContent:\n${await fileObj.readAsString()}";
                } else {
                  content = "[File: ${m.name}]";
                }
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
      if (!_isGenerating) return; // Guard before stream

      await for (final token in sendMessageStream(fullPrompt, historyList)) {
        if (!_isGenerating) break;
        await Future.delayed(const Duration(milliseconds: 10));
        buffer += token;
        final index = _messages.indexWhere((m) => m.id == aiId);
        if (index != -1) {
          _messages[index] = types.TextMessage(
            author: _aiUser,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: aiId,
            text: buffer,
          );
          notifyListeners();
        }
      }

      await _saveMessageToFirestore({
        'id': aiId,
        'authorId': _aiUser.id,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
        'text': buffer,
      });

      _isTyping = false;
      notifyListeners();
      
      if (_isGenerating) {
        _updateSuggestions(buffer);
      }

      final index = _messages.indexWhere((m) => m.id == aiId);
      if (index != -1) {
        // Trigger animations via provider or callback if needed
      }
    } catch (e) {
      print("AI Error: $e");
      _isTyping = false;
      notifyListeners();
    } finally {
      _isTyping = false;
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> _updateSuggestions(String lastAiResponse) async {
    if (!_isGenerating) return;
    
    final prompt =
        "Based on the following AI response, generate 3 short, relevant, and engaging follow-up questions for the user to ask next. Return ONLY a JSON list of strings, exactly in this format: [\"Question 1\", \"Question 2\", \"Question 3\"]. Do not include any other text or explanation. AI Response: $lastAiResponse";

    try {
      String fullResponse = "";
      await for (final token in sendMessageStream(prompt, [])) {
        if (!_isGenerating) break;
        fullResponse += token;
      }

      if (fullResponse.contains("[") && fullResponse.contains("]")) {
        final start = fullResponse.indexOf("[");
        final end = fullResponse.lastIndexOf("]") + 1;
        final jsonPart = fullResponse.substring(start, end);

        final List<dynamic> newSuggestions = jsonDecode(jsonPart);
        if (newSuggestions.isNotEmpty) {
          _listSuggestion.clear();
          _listSuggestion.addAll(newSuggestions.map((e) => e.toString()));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error updating suggestions: $e");
    }
  }

  Future<void> pickImageFromCamera() async {
    if (_isPickerActive) return;
    _isPickerActive = true;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        selectedImage = File(pickedFile.path);
        notifyListeners();
      }
    } finally {
      _isPickerActive = false;
    }
  }

  Future<void> pickImageFromGallery() async {
    if (_isPickerActive) return;
    _isPickerActive = true;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        selectedImage = File(pickedFile.path);
        notifyListeners();
      }
    } finally {
      _isPickerActive = false;
    }
  }

  Future<void> pickFile() async {
    if (_isPickerActive) return;
    _isPickerActive = true;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String extension = result.files.single.extension?.toLowerCase() ?? '';
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          selectedImage = file;
        } else {
          selectedFile = file;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    } finally {
      _isPickerActive = false;
    }
  }

  void removeSelectedImage() {
    selectedImage = null;
    notifyListeners();
  }

  void removeSelectedFile() {
    selectedFile = null;
    notifyListeners();
  }

  void listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            if (val == 'done' || val == 'notListening') {
              _isListening = false;
              notifyListeners();
            }
          },
          onError: (val) {
            _isListening = false;
            notifyListeners();
          },
          debugLogging: true,
        );

        if (available) {
          _isListening = true;
          notifyListeners();

          await _speech.listen(
            onResult: (val) {
              textController.text = val.recognizedWords;
              textController.selection = TextSelection.fromPosition(
                TextPosition(offset: textController.text.length),
              );
              notifyListeners();
            },
            localeId: 'en_US',
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
            pauseFor: const Duration(seconds: 20),
            listenFor: const Duration(minutes: 1),
            cancelOnError: true,
          );
        }
      } catch (e) {
        debugPrint('STT initialization error: $e');
        _isListening = false;
        notifyListeners();
      }
    } else {
      _isListening = false;
      notifyListeners();
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('STT stop error: $e');
      }
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
