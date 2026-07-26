import 'dart:async';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:flutter/material.dart';

/// Chat input bar with text field and attachment buttons
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isRecording;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final VoidCallback? onPickSignableDoc;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.isRecording,
    required this.onSendText,
    required this.onPickImage,
    required this.onPickGallery,
    required this.onPickFile,
    this.onPickSignableDoc,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  late AnimationController _recordingAnimController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _recordingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _recordingTimer?.cancel();
    _recordingAnimController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording && !oldWidget.isRecording) {
      _startRecordingTimer();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopRecordingTimer();
    }
  }

  void _startRecordingTimer() {
    _recordingDuration = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration++);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingDuration = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: widget.isRecording ? _buildRecordingBar() : _buildInputBar(),
    );
  }

  Widget _buildInputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AttachmentButton(
          onPickGallery: widget.onPickGallery,
          onPickFile: widget.onPickFile,
          onPickSignableDoc: widget.onPickSignableDoc,
          isLoading: widget.isLoading,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdaptiveGlassLayer(
            borderRadius: BorderRadius.circular(30),
            sigma: 12,
            fallbackColor: ChatGlassTheme.waterFillStrong,
            fallbackBorder: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              decoration: BoxDecoration(
                color: ChatGlassTheme.waterFill,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: ChatGlassTheme.body(fontSize: 16),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Write your message',
                  hintStyle: ChatGlassTheme.muted(fontSize: 16),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => widget.onSendText(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _hasText
              ? _buildGoldSend(onTap: widget.onSendText)
              : ChatGlassIconButton(
                  key: const ValueKey('camera'),
                  icon: Icons.camera_alt_outlined,
                  onPressed: widget.onPickImage,
                  size: 40,
                  iconColor: ChatGlassTheme.silverLight,
                ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: widget.isLoading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ChatGlassTheme.gold,
                  ),
                )
              : ChatGlassIconButton(
                  key: const ValueKey('mic'),
                  icon: Icons.mic_none_rounded,
                  onPressed: widget.onStartRecording,
                  size: 40,
                  iconColor: ChatGlassTheme.silverLight,
                ),
        ),
      ],
    );
  }

  Widget _buildGoldSend({required VoidCallback onTap}) {
    return Material(
      key: const ValueKey('send'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ChatGlassTheme.goldButtonGradient,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: ChatGlassTheme.gold.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.send_rounded,
              size: 20, color: Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        ChatGlassButton(
          label: 'Cancel',
          icon: Icons.delete_outline,
          variant: ChatGlassButtonVariant.silver,
          onPressed: widget.onCancelRecording,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          fontSize: 14,
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: _recordingAnimController,
          builder: (context, child) {
            return Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(
                        alpha: 0.5 + _recordingAnimController.value * 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: ChatGlassTheme.body(
                    fontSize: 16,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onStopRecording,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ChatGlassTheme.goldButtonGradient,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Icon(
                Icons.stop,
                color: Color(0xFF1A1A1A),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class _AttachmentButton extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final VoidCallback? onPickSignableDoc;
  final bool isLoading;

  const _AttachmentButton({
    required this.onPickGallery,
    required this.onPickFile,
    this.onPickSignableDoc,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isLoading,
      onSelected: (value) {
        switch (value) {
          case 'image':
            onPickGallery();
            break;
          case 'file':
            onPickFile();
            break;
          case 'signable_doc':
            onPickSignableDoc?.call();
            break;
        }
      },
      offset: const Offset(0, -180),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1A2438),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              const Icon(Icons.image, color: ChatGlassTheme.gold),
              const SizedBox(width: 12),
              Text('Image', style: ChatGlassTheme.body()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'file',
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file,
                  color: ChatGlassTheme.silverLight),
              const SizedBox(width: 12),
              Text('File', style: ChatGlassTheme.body()),
            ],
          ),
        ),
        if (onPickSignableDoc != null)
          PopupMenuItem(
            value: 'signable_doc',
            child: Row(
              children: [
                const Icon(Icons.draw, color: ChatGlassTheme.gold),
                const SizedBox(width: 12),
                Text('Document for Signing', style: ChatGlassTheme.body()),
              ],
            ),
          ),
      ],
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ChatGlassTheme.silverButtonGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.attach_file,
          size: 20,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}
