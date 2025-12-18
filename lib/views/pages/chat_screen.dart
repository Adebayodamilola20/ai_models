import 'package:ai_models/views/pages/aivoicetts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:lucide_icons/lucide_icons.dart';
import 'api_kwy.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'hugging.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: 'user-id');
  final _aiUser = const types.User(id: 'ai-id', firstName: 'AI');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool isTyping = false;
  bool hasText = false;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        hasText = _textController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
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

    // Capture image and clear selection immediately to avoid double sends
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
        // Fallback or ignore image if decoding fails
      }
    }

    final aiId = "${DateTime.now()}-ai";
    final aiPlaceholderMsg = types.TextMessage(
      author: _aiUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: aiId,
      text: "",
    );

    // Atomic update of the message list
    setState(() {
      _messages.insert(0, userMsg);
      if (imageMsg != null) {
        _messages.insert(0, imageMsg);
      }
      _messages.insert(0, aiPlaceholderMsg);
    });

    try {
      String aiResponse = "";

      if (imageToSend != null) {
        aiResponse = await HuggingFaceService.analyzeImage(
          imageToSend,
          message.text,
        );
      } else {
        String buffer = "";
        await for (final token in streamMessageToMistral(message.text)) {
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
        setState(() => isTyping = false);
        return;
      }

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

  Widget _buildCustomInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Ask COGICHAT',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
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
                      icon: const Icon(Icons.add, size: 24),
                      color: Colors.grey[700],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.mic, size: 22),
                      color: Colors.grey[700],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: hasText
                          ? () {
                              if (_textController.text.trim().isNotEmpty) {
                                _handleSendPressed(
                                  types.PartialText(text: _textController.text),
                                );
                                _textController.clear();
                                setState(() {
                                  selectedImage = null;
                                });
                              }
                            }
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VoiceChatScreen(),
                                ),
                              );
                            },
                      icon: Icon(
                        hasText ? LucideIcons.send : LucideIcons.box,
                        size: 20,
                      ),
                      color: hasText ? Colors.blue : Colors.black,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          "Hello",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        centerTitle: false,
        leading: IconButton(
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          icon: const Icon(LucideIcons.menu),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(LucideIcons.bookOpen),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text(''),
              centerTitle: false,
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.chat),
                    title: Text(
                      'New chats',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () {},
                  ),
                  AppBar(title: Text('Recents'),
                  centerTitle: false,),

                  ListTile(title: Text('Menu Item 1')),
                  ListTile(title: Text('Menu Item 2')),
                  ListTile(title: Text('Menu Item 3')),
                  ListTile(title: Text('Menu Item 4')),
                  ListTile(title: Text('Menu Item 5')),
                  ListTile(title: Text('Menu Item 6')),
                  ListTile(title: Text('Menu Item 7')),
                  ListTile(title: Text('Menu Item 8')),
                  ListTile(title: Text('Menu Item 9')),
                  ListTile(title: Text('Menu Item 10')),
                  ListTile(title: Text('Menu Item 11')),
                  ListTile(title: Text('Menu Item 12')),
                ],
              ),
            ),

            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: const SafeArea(
                top: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue,
                      child: Text('P', style: TextStyle(color: Colors.white)),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.settings, color: Colors.grey),
                  ],
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
        typingIndicatorOptions: TypingIndicatorOptions(
          typingUsers: isTyping ? [_aiUser] : [],
        ),
        customBottomWidget: _buildCustomInput(),
        theme: DefaultChatTheme(
          inputBackgroundColor: Colors.grey[100]!,
          inputTextColor: Colors.black,
          primaryColor: const Color(0xFFDEF2FF),
          secondaryColor: Colors.white,
          backgroundColor: Colors.white,
          sentMessageBodyTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
          receivedMessageBodyBoldTextStyle: const TextStyle(),
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
