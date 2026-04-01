import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:lucide_icons/lucide_icons.dart';
import '../chat_view_model.dart';

class ChatInput extends StatelessWidget {
  final ChatViewModel viewModel;

  const ChatInput({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardHeight > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (viewModel.selectedImage != null) _buildImagePreview(),
        if (viewModel.selectedFile != null) _buildFilePreview(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Container(
            margin: EdgeInsets.only(
              bottom: isKeyboardOpen ? 10 : 0,
              left: isKeyboardOpen ? 10 : 0,
              right: isKeyboardOpen ? 10 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(context),
                const SizedBox(height: 16),
                _buildActionRow(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              viewModel.selectedImage!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () => viewModel.removeSelectedImage(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 53,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                viewModel.selectedFile!.path.split('/').last,
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
              onPressed: () => viewModel.removeSelectedFile(),
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return TextField(
      controller: viewModel.textController,
      focusNode: viewModel.focusNode,
      minLines: 1,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        fontSize: 16,
      ),
      maxLines: 6,
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
          viewModel.handleSendPressed(types.PartialText(text: text));
          viewModel.textController.clear();
        }
      },
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _openAttachmentMenu(context),
          icon: Icon(
            Icons.add,
            size: 24,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        ElevatedButton(
          onPressed: () => viewModel.toggleDeepThink(),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(55, 29),
            padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 13),
            backgroundColor: viewModel.isBlue
                ? const Color.fromARGB(255, 76, 174, 254).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ).copyWith(elevation: WidgetStateProperty.all(0)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'DeepThink',
              style: TextStyle(
                color: viewModel.isBlue
                    ? Colors.blue
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => viewModel.listen(),
          icon: Icon(
            viewModel.isListening ? Icons.stop : LucideIcons.mic,
            color: viewModel.isListening ? Colors.red : Colors.blue,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 7),
        IconButton(
          onPressed: () {
            if (viewModel.isGenerating) {
              viewModel.stopResponse();
            } else if (viewModel.textController.text.trim().isNotEmpty) {
              viewModel.handleSendPressed(
                types.PartialText(text: viewModel.textController.text),
              );
              viewModel.textController.clear();
            }
          },
          icon: Icon(
            viewModel.isGenerating
                ? Icons.stop_circle_outlined
                : LucideIcons.send,
            size: 20,
          ),
          color: viewModel.isGenerating ? Colors.red : Colors.blue,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _openAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.12),
        ),
      ),

      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(22.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBottomSheetHeader(context),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildOptionCard(
                          context,
                          icon: Icons.camera_alt_outlined,
                          label: 'Camera',
                          onTap: () async {
                            Navigator.pop(context);
                            await viewModel.pickImageFromCamera();
                          },
                        ),
                        _buildOptionCard(
                          context,
                          icon: Icons.photo_outlined,
                          label: 'Photos',
                          onTap: () async {
                            Navigator.pop(context);
                            await viewModel.pickImageFromGallery();
                          },
                        ),
                        _buildOptionCard(
                          context,
                          icon: Icons.file_upload_outlined,
                          label: 'Files',
                          onTap: () async {
                            Navigator.pop(context);
                            await viewModel.pickFile();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetHeader(BuildContext context) {
    return Row(
      children: [
        Center(
          child: Text(
            'Add to Chat',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
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
          color: Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
