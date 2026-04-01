import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:provider/provider.dart';
import '../../../shared/ProviderX/provider.dart';
import '../chat_view_model.dart';
import 'streaming_text.dart';
import '../../../services/tts_service.dart';

class ChatBubble extends StatelessWidget {
  final types.Message message;
  final Widget child;
  final ChatViewModel viewModel;
  final Animation<double> animation;
  final List<AnimationController> iconControllers;
  final Function(String, {IconData? icon, Color? color}) onShowSnackbar;
  final ttsService = TtsService();

  ChatBubble({
    super.key,
    required this.message,
    required this.child,
    required this.viewModel,
    required this.animation,
    required this.iconControllers,
    required this.onShowSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.watch<Userprovider>().accentColor;
    final isMe = message.author.id == viewModel.user.id;

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
                        ? constraints.maxWidth * 0.8
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
                        : Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: isMe
                        ? Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          )
                        : null,
                    boxShadow: [
                      if (isMe && accentColor != Colors.transparent)
                        BoxShadow(
                          color: accentColor.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: isMe
                      ? _buildUserMessage(context)
                      : _buildAiMessage(constraints),
                ),
              ),
            ),
            if (message.author.id != viewModel.user.id &&
                message is types.TextMessage &&
                (message as types.TextMessage).text.isNotEmpty &&
                iconControllers.isNotEmpty)
              _buildActionIcons(context),
          ],
        );
      },
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        final position = details.globalPosition;
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(position.dy, position.dx, 0, 0),
          items: const [
            PopupMenuItem(value: 'Copy', child: Text('Copy')),
            PopupMenuItem(value: 'Paste', child: Text('Paste')),
          ],
        ).then((value) {
          if (value == 'Copy') {
            Clipboard.setData(
              ClipboardData(text: (message as types.TextMessage).text),
            );
            onShowSnackbar("Copied to clipboard", icon: Icons.check_circle);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SelectionArea(child: child),
      ),
    );
  }

  Widget _buildAiMessage(BoxConstraints constraints) {
    return Container(
      width: constraints.maxWidth - 45,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: SelectionArea(child: child),
    );
  }

  Widget _buildActionIcons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnimatedIcon(context, iconControllers[0], Icons.copy, () {
            Clipboard.setData(
              ClipboardData(text: (message as types.TextMessage).text),
            );
            onShowSnackbar(
              "Copied to clipboard",
              icon: Icons.check_circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            );
          }),
          const SizedBox(width: 2),
          _buildAnimatedIcon(
            context,
            iconControllers[3],
            viewModel.isLiked(message.id)
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            () {
              viewModel.toggleLike(message.id);
              if (viewModel.isLiked(message.id)) {
                onShowSnackbar(
                  "Thank you for your feedback!",
                  icon: Icons.thumb_up,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                );
              }
            },
            color: viewModel.isLiked(message.id) ? Colors.blue : null,
          ),
          const SizedBox(width: 2),
          _buildAnimatedIcon(
            context,
            iconControllers[4],
            viewModel.isDisliked(message.id)
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            () {
              viewModel.toggleDislike(message.id);
              if (viewModel.isDisliked(message.id)) {
                onShowSnackbar(
                  "Thank you for your feedback!",
                  icon: Icons.thumb_down,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                );
              }
            },
            color: viewModel.isDisliked(message.id) ? Colors.red : null,
          ),
          const SizedBox(width: 2),
          _buildAnimatedIcon(
            context,
            iconControllers[2],
            LucideIcons.volumeX,
            () {
              // Volume logic
            },
          ),
          const SizedBox(width: 2),
          _buildAnimatedIcon(
            context,
            iconControllers[2],
            ttsService.isSpeaking ? Icons.stop : Icons.volume_up,
            () async {
              if (ttsService.isSpeaking) {
                await ttsService.stop();
                onShowSnackbar("Stopped Speaking");
              } else {
                await ttsService.speak((message as types.TextMessage).text);
                onShowSnackbar("Speaking...");
              }
              // More options logic
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(
    BuildContext context,
    AnimationController controller,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) {
    final curAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    return FadeTransition(
      opacity: curAnimation,
      child: ScaleTransition(
        scale: curAnimation,
        child: SizedBox(
          width: 28,
          height: 24,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 16,
              color:
                  color ??
                  (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

// Separate helper for Text Message building to stay organized
Widget buildTextMessage(
  types.TextMessage message,
  int messageWidth,
  BuildContext context,
  Function(String, {IconData? icon}) onShowSnackbar,
) {
  final text = message.text;
  if (text.contains("```")) {
    final parts = text.split("```");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.asMap().entries.map((entry) {
        final index = entry.key;
        final part = entry.value;
        if (index % 2 != 0) {
          return _buildCodeBlock(part, messageWidth, context, onShowSnackbar);
        } else {
          return _buildStreamingText(part, messageWidth, context);
        }
      }).toList(),
    );
  }
  return _buildStreamingText(text, messageWidth, context);
}

Widget _buildCodeBlock(
  String part,
  int messageWidth,
  BuildContext context,
  Function(String, {IconData? icon}) onShowSnackbar,
) {
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

  var customTheme = Map<String, TextStyle>.from(atomOneDarkTheme);
  customTheme['root'] = TextStyle(
    backgroundColor: Colors.transparent,
    color: atomOneDarkTheme['root']?.color,
  );

  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
            constraints: BoxConstraints(maxWidth: messageWidth.toDouble() - 40),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: HighlightView(
                      code,
                      language: language,
                      theme: customTheme,
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
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
                        Clipboard.setData(ClipboardData(text: code)).then((_) {
                          onShowSnackbar(
                            "Copied to clipboard",
                            icon: Icons.check_circle,
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
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
                        color: Colors.white.withOpacity(0.3),
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
}

Widget _buildStreamingText(
  String text,
  int messageWidth,
  BuildContext context,
) {
  return Container(
    constraints: BoxConstraints(maxWidth: messageWidth.toDouble() - 30),
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
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
}
