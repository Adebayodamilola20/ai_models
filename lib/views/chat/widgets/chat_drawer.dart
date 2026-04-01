import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../shared/ProviderX/provider.dart';
import '../chat_view_model.dart';

class ChatDrawer extends StatelessWidget {
  final ChatViewModel viewModel;
  final VoidCallback onShowSettings;
  final Function(String, {IconData? icon, Color? color}) onShowSnackbar;

  const ChatDrawer({
    super.key,
    required this.viewModel,
    required this.onShowSettings,
    required this.onShowSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Drawer(
        backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
        width: 350,
        child: StaggeredDrawerContent(
          viewModel: viewModel,
          onShowSettings: onShowSettings,
          onShowSnackbar: onShowSnackbar,
        ),
      ),
    );
  }
}

class StaggeredDrawerContent extends StatefulWidget {
  final ChatViewModel viewModel;
  final VoidCallback onShowSettings;
  final Function(String, {IconData? icon}) onShowSnackbar;

  const StaggeredDrawerContent({
    super.key,
    required this.viewModel,
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
                onTap: () {
                  widget.viewModel.startNewChat();
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
                      Icon(
                        LucideIcons.layoutGrid,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.black54,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Explore Apps',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
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
                      final isSelected =
                          docs[index].id == widget.viewModel.currentChatId;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 600),
                        child: SlideAnimation(
                          horizontalOffset: -100.0,
                          child: FadeInAnimation(
                            child: _StaggeredItem(
                              index: index + 3,
                              animation: _controller,
                              isExitOnly: true,
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
                                        onTap: () {
                                          widget.viewModel.loadChat(
                                            docs[index].id,
                                          );
                                          Navigator.pop(context);
                                        },
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
            index: 10,
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
