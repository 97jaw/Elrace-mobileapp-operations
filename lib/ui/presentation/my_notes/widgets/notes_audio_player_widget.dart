import 'dart:io';

import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

/// Compact audio playback for note create / detail.
///
/// [audioUrl] may be a remote `https://…` download URL **or** a local file
/// path (used while the create screen is still uploading).
class NotesAudioPlayerWidget extends StatefulWidget {
  const NotesAudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.durationSeconds,
  });

  final String audioUrl;
  final int? durationSeconds;

  @override
  State<NotesAudioPlayerWidget> createState() => _NotesAudioPlayerWidgetState();
}

class _NotesAudioPlayerWidgetState extends State<NotesAudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  String? _error;
  String? _loadedSource;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(NotesAudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _init();
    }
  }

  Future<void> _init() async {
    final source = widget.audioUrl.trim();
    if (source.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _loadedSource = null;
        });
      }
      return;
    }
    if (source == _loadedSource && !_loading && _error == null) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final isRemote = source.startsWith('http://') ||
          source.startsWith('https://') ||
          source.startsWith('gs://');
      if (isRemote) {
        await _player.setUrl(source);
      } else {
        final file = File(source);
        if (!await file.exists()) {
          throw StateError('Local audio file missing');
        }
        await _player.setFilePath(source);
      }
      _loadedSource = source;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load audio';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl.trim().isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            SizedBox(
              width: 16.w,
              height: 16.w,
              child: const CircularProgressIndicator(
                color: NotesTheme.bronze,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'Uploading audio…',
              style: GoogleFonts.poppins(
                color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: const Center(
          child: CircularProgressIndicator(
              color: NotesTheme.bronze, strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Text(
        _error!,
        style: GoogleFonts.poppins(
          color: NotesTheme.textPrimary.withValues(alpha: 0.5),
          fontSize: 12.sp,
        ),
      );
    }

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Row(
          children: [
            IconButton(
              onPressed: () async {
                if (playing) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
              icon: Icon(
                playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: NotesTheme.bronze,
                size: 36.sp,
              ),
            ),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, posSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final total = _player.duration ??
                      (widget.durationSeconds != null
                          ? Duration(seconds: widget.durationSeconds!)
                          : Duration.zero);
                  final maxMs =
                      total.inMilliseconds <= 0 ? 1.0 : total.inMilliseconds.toDouble();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 6.r),
                          overlayShape:
                              RoundSliderOverlayShape(overlayRadius: 12.r),
                          activeTrackColor: NotesTheme.bronze,
                          inactiveTrackColor:
                              NotesTheme.bronze.withValues(alpha: 0.2),
                          thumbColor: NotesTheme.bronze,
                        ),
                        child: Slider(
                          value: pos.inMilliseconds
                              .clamp(0, maxMs.toInt())
                              .toDouble(),
                          max: maxMs,
                          onChanged: (v) =>
                              _player.seek(Duration(milliseconds: v.round())),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fmt(pos),
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                color: NotesTheme.textPrimary
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            Text(
                              _fmt(total),
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                color: NotesTheme.textPrimary
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
