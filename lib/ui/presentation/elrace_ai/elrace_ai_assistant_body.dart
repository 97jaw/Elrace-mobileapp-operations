import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class _AiMessage {
  const _AiMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

/// Shared AI chat body — user messages get a "Coming soon" reply.
class ElraceAiAssistantBody extends StatefulWidget {
  const ElraceAiAssistantBody({
    super.key,
    required this.title,
    required this.subtitle,
    this.suggestions = const [],
    this.bottomPadding = 24,
    this.comingSoonReply = 'Coming soon',
  });

  final String title;
  final String subtitle;
  final List<String> suggestions;
  final double bottomPadding;
  final String comingSoonReply;

  @override
  State<ElraceAiAssistantBody> createState() => _ElraceAiAssistantBodyState();
}

class _ElraceAiAssistantBodyState extends State<ElraceAiAssistantBody> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_AiMessage>[];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_AiMessage(text: text, isUser: true));
      _messages.add(_AiMessage(text: widget.comingSoonReply, isUser: false));
      _inputCtrl.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions.isNotEmpty
        ? widget.suggestions
        : const [
            'Summarize my pending approvals',
            'Which projects need attention?',
            'Explain this month purchase trend',
          ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            children: [
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEDE9FE).withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.65),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: ElraceAiTheme.accentPurple,
                          size: 22.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: ElraceAiTheme.accentDeep,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        height: 1.45,
                        color: ElraceAiTheme.textSecondary,
                      ),
                    ),
                    if (_messages.isEmpty) ...[
                      SizedBox(height: 16.h),
                      for (final s in suggestions) ...[
                        _SuggestionChip(text: s, onTap: () => _send(s)),
                        SizedBox(height: 8.h),
                      ],
                    ],
                  ],
                ),
              ),
              if (_messages.isNotEmpty) ...[
                SizedBox(height: 14.h),
                for (final msg in _messages) ...[
                  _ChatBubble(message: msg),
                  SizedBox(height: 8.h),
                ],
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, widget.bottomPadding),
          child: Container(
            padding: EdgeInsets.fromLTRB(14.w, 6.h, 6.w, 6.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              color: Colors.white.withValues(alpha: 0.58),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask Elrace AI…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: ElraceAiTheme.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: GoogleFonts.poppins(fontSize: 12.sp),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _send(),
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 0.78.sw),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF4A9FD4).withValues(alpha: 0.15)
              : const Color(0xFFEDE9FE).withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.r),
            topRight: Radius.circular(14.r),
            bottomLeft: Radius.circular(isUser ? 14.r : 4.r),
            bottomRight: Radius.circular(isUser ? 4.r : 14.r),
          ),
          border: Border.all(
            color: isUser
                ? const Color(0xFF4A9FD4).withValues(alpha: 0.25)
                : ElraceAiTheme.accentPurple.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Icon(
                Icons.auto_awesome,
                size: 14.sp,
                color: ElraceAiTheme.accentPurple,
              ),
              SizedBox(width: 6.w),
            ],
            Flexible(
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w600,
                  color: isUser ? ElraceAiTheme.textPrimary : ElraceAiTheme.accentDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: ElraceAiTheme.accentPurple.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: ElraceAiTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
