import 'dart:async';
import 'dart:ui';

import 'package:el_race/ui/presentation/clients_vendors/theme/clients_vendors_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared list chrome: glass company header + title row (icon + title + search)
/// with auto-hiding search field (6s idle when empty).
class ClientsListChrome extends StatefulWidget {
  const ClientsListChrome({
    super.key,
    required this.title,
    required this.icon,
    required this.onSearchChanged,
    this.onBack,
  });

  final String title;
  final IconData icon;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onBack;

  @override
  State<ClientsListChrome> createState() => _ClientsListChromeState();
}

class _ClientsListChromeState extends State<ClientsListChrome> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _searchOpen = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    if (!_searchOpen) return;
    _hideTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_controller.text.trim().isNotEmpty) return;
      setState(() => _searchOpen = false);
      _focus.unfocus();
    });
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
      _armHideTimer();
    } else {
      _hideTimer?.cancel();
      _controller.clear();
      widget.onSearchChanged('');
      _focus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ContextualGlassChromeHeader(
          showBack: false,
          onLightSurface: false,
          transparentGlassBar: true,
          logoOpacity: 0.7,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack ??
                    () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: Icon(
                  widget.icon,
                  color: ClientsVendorsTheme.iconAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: _toggleSearch,
                icon: Icon(
                  _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _searchOpen
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: (v) {
                      widget.onSearchChanged(v);
                      _armHideTimer();
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    cursorColor: ClientsVendorsTheme.iconAccent,
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.10),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: ClientsVendorsTheme.iconAccent,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Themed partner/client avatar with initials fallback.
class ClientsPartnerAvatar extends StatelessWidget {
  const ClientsPartnerAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.size = 44,
  });

  final String imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: ClientsVendorsTheme.iconAccent.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Center(
              child: Text(
                initial,
                style: GoogleFonts.poppins(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: ClientsVendorsTheme.iconAccent,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w700,
                    color: ClientsVendorsTheme.iconAccent,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Soft press scale used by feature cards.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Shared navy stacked background for Clients list screens.
class ClientsListScaffold extends StatelessWidget {
  const ClientsListScaffold({
    super.key,
    required this.chrome,
    required this.body,
  });

  final Widget chrome;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ClientsVendorsTheme.deepLight,
                  ClientsVendorsTheme.deepMid,
                  ClientsVendorsTheme.deepDark,
                ],
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.55),
                  radius: 0.9,
                  colors: [
                    ClientsVendorsTheme.glowBright,
                    ClientsVendorsTheme.glowMid,
                    ClientsVendorsTheme.glowSoft,
                    ClientsVendorsTheme.glowEdge,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.25, 0.45, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              chrome,
              Expanded(child: body),
            ],
          ),
        ],
      ),
    );
  }
}
