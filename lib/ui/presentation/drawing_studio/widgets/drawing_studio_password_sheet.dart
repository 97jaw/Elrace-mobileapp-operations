import 'dart:ui';

import 'package:el_race/core/drawing_studio/drawing_studio_cognito_client.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centered authorize dialog — password only (Cognito email from login, never shown).
Future<bool?> showDrawingStudioAuthorizeDialog({
  required BuildContext context,
  required String email,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'drawing_studio_authorize',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: _DrawingStudioAuthorizeDialog(email: email),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// @deprecated Use [showDrawingStudioAuthorizeDialog].
Future<bool?> showDrawingStudioPasswordSheet({
  required BuildContext context,
  required String email,
}) =>
    showDrawingStudioAuthorizeDialog(context: context, email: email);

class _DrawingStudioAuthorizeDialog extends StatefulWidget {
  const _DrawingStudioAuthorizeDialog({required this.email});

  final String email;

  @override
  State<_DrawingStudioAuthorizeDialog> createState() =>
      _DrawingStudioAuthorizeDialogState();
}

class _DrawingStudioAuthorizeDialogState
    extends State<_DrawingStudioAuthorizeDialog> {
  final _passwordController = TextEditingController();
  final _client = DrawingStudioCognitoClient();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your Cognito password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _client.signIn(email: widget.email, password: password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DrawingStudioAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Unable to authorize. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width - 40.w;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW.clamp(280.0, 400.0)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.ur),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 18.uh, 20.w, 18.uh),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22.ur),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A2A4F).withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.ur),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3E7BFA), Color(0xFF1A2A4F)],
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 20.usp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Authorize Studio',
                              style: GoogleFonts.poppins(
                                fontSize: 16.usp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A2A4F),
                              ),
                            ),
                            Text(
                              'Enter your Cognito password',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5.usp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF5A6A82),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF7A849C),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.uh),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_submitting) _submit();
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 14.usp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A2A4F),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF2F4F8),
                      hintText: 'Password',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.usp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9AA5B5),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 14.uh,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.ur),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF7A849C),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 10.uh),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(
                        fontSize: 12.usp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE63946),
                      ),
                    ),
                  ],
                  SizedBox(height: 16.uh),
                  SizedBox(
                    height: 48.uh,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2A4F),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF1A2A4F).withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.ur),
                        ),
                      ),
                      child: _submitting
                          ? SizedBox(
                              width: 22.w,
                              height: 22.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.poppins(
                                fontSize: 14.usp,
                                fontWeight: FontWeight.w700,
                              ),
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
}
