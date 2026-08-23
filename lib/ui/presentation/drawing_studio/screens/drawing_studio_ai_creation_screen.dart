import 'package:el_race/core/drawing_studio/drawing_studio_api_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_route_names.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI Creation chat — `POST /generate` with `{ brief }`, then poll status.
class DrawingStudioAiCreationScreen extends StatefulWidget {
  const DrawingStudioAiCreationScreen({super.key});

  @override
  State<DrawingStudioAiCreationScreen> createState() =>
      _DrawingStudioAiCreationScreenState();
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class _DrawingStudioAiCreationScreenState
    extends State<DrawingStudioAiCreationScreen> {
  final _api = DrawingStudioApiClient();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Describe the project you want — e.g. “Modern 3BR villa 280m² with pool, Abu Dhabi”.',
      isUser: false,
    ),
  ];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final brief = _controller.text.trim();
    if (brief.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text: brief, isUser: true));
      _controller.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final accepted = await _api.generateBrief(brief);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                'Started “${accepted.title ?? 'project'}”. Opening generation status…',
            isUser: false,
          ),
        );
        _sending = false;
      });
      _scrollToEnd();
      Navigator.of(context).pushNamed(
        DrawingStudioRouteNames.generationStatus,
        arguments: {
          'project_id': accepted.projectId,
          'title': accepted.title ?? 'AI Creation',
          'progress': accepted.progress,
        },
      );
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _messages.add(_ChatMessage(text: e.message, isUser: false));
        _sending = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to start generation.';
        _messages.add(
          const _ChatMessage(
            text: 'Unable to start generation. Please try again.',
            isUser: false,
          ),
        );
        _sending = false;
      });
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          const DrawingStudioChromeHeader(),
          const DrawingStudioHeadingCard(title: 'AI Creation'),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.usp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE63946),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(16.w, 8.uh, 16.w, 16.uh),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 10.uh),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.uh,
                    ),
                    constraints: BoxConstraints(maxWidth: 0.78.sw),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF1A2A4F)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14.ur),
                      border: msg.isUser
                          ? null
                          : Border.all(color: const Color(0xFFE4E8F0)),
                    ),
                    child: Text(
                      msg.text,
                      style: GoogleFonts.poppins(
                        fontSize: 13.usp,
                        fontWeight: FontWeight.w500,
                        color: msg.isUser
                            ? Colors.white
                            : const Color(0xFF1A2A4F),
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 6.uh, 12.w, 10.uh),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Describe your drawing…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.uh,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.ur),
                          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.ur),
                          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Material(
                    color: const Color(0xFF1A2A4F),
                    borderRadius: BorderRadius.circular(14.ur),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      borderRadius: BorderRadius.circular(14.ur),
                      child: SizedBox(
                        width: 48.w,
                        height: 48.w,
                        child: Center(
                          child: _sending
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20.usp,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
