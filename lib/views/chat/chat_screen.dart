import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../shared/ProviderX/provider.dart';
import '../pages/setting.dart';
import 'chat_view_model.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_drawer.dart';
import '../../../services/tts_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late ChatViewModel _viewModel;
  final Map<String, AnimationController> _messageAnimations = {};
  final Map<String, List<AnimationController>> _iconAnimations = {};
  OverlayEntry? _currentOverlay;

  @override
  void initState() {
    super.initState();
    _viewModel = ChatViewModel();
    TtsService().initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    for (var c in _messageAnimations.values) {
      c.dispose();
    }
    for (var cl in _iconAnimations.values) {
      for (var c in cl) {
        c.dispose();
      }
    }
    _currentOverlay?.remove();
    super.dispose();
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
        controllers.add(
          AnimationController(
            duration: const Duration(milliseconds: 300),
            vsync: this,
          ),
        );
      }
      _iconAnimations[messageId] = controllers;
    }

    final controllers = _iconAnimations[messageId]!;
    if (message is types.TextMessage &&
        message.text.isNotEmpty &&
        !_viewModel.isTyping &&
        controllers[0].status == AnimationStatus.dismissed) {
      for (int i = 0; i < controllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) controllers[i].forward();
        });
      }
    }
    return controllers;
  }

  void _showTopSnackbar(String message, {Color? color, IconData? icon}) {
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
                      width: 0.5,
                    ),
                  ),
                  child: Row(
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            key: GlobalKey<ScaffoldState>(),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: _buildAppBar(context, vm),
            drawer: ChatDrawer(
              viewModel: vm,
              onShowSettings: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => const SettingsSheet(),
                );
              },
              onShowSnackbar: _showTopSnackbar,
            ),
            floatingActionButton: vm.showBackToBottom
                ? FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.blue,
                    onPressed: vm.scrollToBottom,
                    child: const Icon(
                      Icons.arrow_downward,
                      color: Colors.white,
                    ),
                  )
                : null,
            body: Chat(
              theme: DefaultChatTheme(
                inputBackgroundColor: Colors.transparent,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                primaryColor: context.watch<Userprovider>().accentColor,
                secondaryColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
              ),
              messages: vm.messages,
              onSendPressed: vm.handleSendPressed,
              user: vm.user,
              messageWidthRatio: 1.0,
              showUserAvatars: false,
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: vm.isTyping ? [vm.aiUser] : [],
                customTypingIndicator: vm.isTyping
                    ? _buildTypingIndicator()
                    : null,
              ),
              customBottomWidget: _buildInputWrapper(vm),
              emptyState: _buildEmptyState(context, vm),
              textMessageBuilder:
                  (message, {required messageWidth, required showName}) =>
                      buildTextMessage(
                        message,
                        messageWidth,
                        context,
                        _showTopSnackbar,
                      ),
              bubbleBuilder:
                  (child, {required message, required nextMessageInGroup}) =>
                      ChatBubble(
                        message: message,
                        child: child,
                        viewModel: vm,
                        animation: _getOrCreateAnimation(message.id),
                        iconControllers: _getOrCreateIconAnimations(
                          message.id,
                          message,
                        ),
                        onShowSnackbar: _showTopSnackbar,
                      ),
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
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${(message.size / 1024).toStringAsFixed(1)} KB",
                              style: const TextStyle(
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
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, ChatViewModel vm) {
    return AppBar(
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      title: Text(
        vm.currentChatTitle,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: vm.startNewChat,
          icon: const Icon(LucideIcons.plus, size: 20),
        ),
      ],
      leading: Builder(
        builder: (context) => IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: Image.asset(
            'assets/images/text-align-start.png',
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: const Text(
        "AI is typing...",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInputWrapper(ChatViewModel vm) {
    return ClipRRect(
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
          child: ChatInput(viewModel: vm),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatViewModel vm) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${context.watch<Userprovider>().firstname.isEmpty ? "User" : context.watch<Userprovider>().firstname}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const Text(
                'Where should we start?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              _buildSuggestionsList(vm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(ChatViewModel vm) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vm.listSuggestion.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                vm.textController.text = vm.listSuggestion[index];
                vm.focusNode.requestFocus();
              },
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(29),
                ),
                child: Center(
                  child: Text(
                    vm.listSuggestion[index],
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
