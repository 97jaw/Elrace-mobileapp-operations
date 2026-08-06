import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

/// Compact audio playback controls for note detail.
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.audioUrl);
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
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: const Center(
          child: CircularProgressIndicator(color: NotesTheme.bronze, strokeWidth: 2),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                    size: 40.sp,
                  ),
                ),
                Expanded(
                  child: StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final total = _player.duration ??
                          Duration(seconds: widget.durationSeconds ?? 0);
                      final maxMs = total.inMilliseconds <= 0
                          ? 1.0
                          : total.inMilliseconds.toDouble();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              activeTrackColor: NotesTheme.bronze,
                              inactiveTrackColor:
                                  NotesTheme.textPrimary.withValues(alpha: 0.15),
                              thumbColor: NotesTheme.bronze,
                            ),
                            child: Slider(
                              value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
                              max: maxMs,
                              onChanged: (v) {
                                _player.seek(Duration(milliseconds: v.round()));
                              },
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fmt(pos),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
                                    color: NotesTheme.textPrimary
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                Text(
                                  _fmt(total),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
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
            ),
          ],
        );
      },
    );
  }
}
