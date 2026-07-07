import 'package:adhan/adhan.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/parayer_widgets/prayer_countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Compact prayer times for the home mid section.
class HomeMidPrayerPanel extends StatefulWidget {
  const HomeMidPrayerPanel({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  State<HomeMidPrayerPanel> createState() => _HomeMidPrayerPanelState();
}

class _HomeMidPrayerPanelState extends State<HomeMidPrayerPanel> {
  PrayerTimes? _pt;
  Prayer? _nextPrayer;
  DateTime? _nextTime;
  Map<String, DateTime>? _aladhan;
  bool _isMuted = false;

  static const _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _applyState(context.read<HomeBloc>().state);
    if (_pt == null) _applyLocalFallback();
    final bloc = context.read<HomeBloc>();
    bloc.add(const InitPrayerTimesEvent());
    bloc.add(const LoadPrayerMuteStateEvent());
  }

  void _applyState(HomeState state) {
    if (state is PrayerTimesLoaded) {
      _pt = state.prayerTimes as PrayerTimes?;
      _nextPrayer = state.nextPrayer as Prayer?;
      _nextTime = state.nextTime;
      _aladhan = state.aladhanTimes;
      _isMuted = state.isSoundMuted;
    } else if (state is PrayerTimesError) {
      _pt = (state.prayerTimes as PrayerTimes?) ?? _pt;
      _isMuted = state.isSoundMuted;
      if (_pt != null && _nextPrayer == null) {
        try {
          final next = _pt!.nextPrayer();
          _nextPrayer = next;
          _nextTime = _pt!.timeForPrayer(next);
        } catch (_) {}
      }
    } else if (state is PrayerMuteStateChanged) {
      _isMuted = state.isMuted;
    }
  }

  void _applyLocalFallback() {
    try {
      final params = CalculationMethod.egyptian.getParameters()
        ..madhab = Madhab.shafi;
      final pt = PrayerTimes.today(
        Coordinates(25.2048, 55.2708),
        params,
      );
      final next = pt.nextPrayer();
      _pt = pt;
      _nextPrayer = next;
      _nextTime = pt.timeForPrayer(next);
      _aladhan = {
        'fajr': pt.fajr,
        'dhuhr': pt.dhuhr,
        'asr': pt.asr,
        'maghrib': pt.maghrib,
        'isha': pt.isha,
        'sunrise': pt.sunrise,
      };
    } catch (_) {}
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('h:mm a', locale).format(dt);
  }

  DateTime? _timeFor(String key) => _aladhan?[key] ?? _prayerDateTime(key);

  DateTime? _prayerDateTime(String key) {
    if (_pt == null) return null;
    switch (key) {
      case 'fajr':
        return _pt!.fajr;
      case 'dhuhr':
        return _pt!.dhuhr;
      case 'asr':
        return _pt!.asr;
      case 'maghrib':
        return _pt!.maghrib;
      case 'isha':
        return _pt!.isha;
      case 'sunrise':
        return _pt!.sunrise;
      default:
        return null;
    }
  }

  Color _textColor(Prayer? p) =>
      _nextPrayer == p ? _gold : Colors.white.withValues(alpha: 0.92);

  String _prayerKey(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'home.Fajr';
      case Prayer.dhuhr:
        return 'home.Dhuhr';
      case Prayer.asr:
        return 'home.Asr';
      case Prayer.maghrib:
        return 'home.Maghrib';
      case Prayer.isha:
        return 'home.Isha';
      default:
        return 'home.Fajr';
    }
  }

  Widget _prayerIcon(Prayer? prayer, Color color) {
    if (prayer == null) {
      return Icon(Icons.wb_twilight_outlined, size: 9.w, color: color);
    }
    final filter = ColorFilter.mode(color, BlendMode.srcIn);
    switch (prayer) {
      case Prayer.fajr:
        return SvgPicture.asset(
          'assets/newapp/newicon/fajar_new.svg',
          width: 9.w,
          height: 9.w,
          colorFilter: filter,
        );
      case Prayer.dhuhr:
        return SvgPicture.asset(
          'assets/newapp/newicon/duhur.svg',
          width: 11.w,
          height: 9.w,
          colorFilter: filter,
        );
      case Prayer.asr:
        return SvgPicture.asset(
          'assets/newapp/newicon/asr_new.svg',
          width: 9.w,
          height: 9.w,
          colorFilter: filter,
        );
      case Prayer.maghrib:
        return SvgPicture.asset(
          'assets/newapp/newicon/maghrib.svg',
          width: 9.w,
          height: 9.w,
          colorFilter: filter,
        );
      case Prayer.isha:
        return Image.asset(
          'assets/newapp/Ellipse 107.png',
          width: 9.w,
          height: 9.w,
          color: color,
          colorBlendMode: BlendMode.srcIn,
        );
      default:
        return Icon(Icons.wb_sunny_outlined, size: 9.w, color: color);
    }
  }

  Widget _prayerCell({
    required String name,
    required String time,
    required Color textColor,
    Prayer? prayer,
  }) {
    final isNext = prayer != null && _nextPrayer == prayer;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          _prayerIcon(prayer, textColor),
          SizedBox(height: 2.h),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 8.sp,
              fontWeight: isNext ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
              height: 1.05,
            ),
          ),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 7.sp,
              fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
              color: textColor.withValues(alpha: 0.92),
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (p, c) =>
          c is PrayerTimesLoaded ||
          c is PrayerTimesError ||
          c is PrayerMuteStateChanged,
      listener: (context, state) {
        setState(() {
          _applyState(state);
          if (_pt == null) _applyLocalFallback();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeGlassTheme.midModePanelHeader(
            onBack: widget.onBack,
            iconColor: Colors.white,
            title: Text(
              'Prayer times',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 12.sp,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                SizedBox(width: 2.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 64.w),
                  child: Text(
                    HomeCityHelper.cachedCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 8.5.sp,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                GestureDetector(
                  onTap: () {
                    context.read<HomeBloc>().add(const InitPrayerTimesEvent());
                    context
                        .read<HomeBloc>()
                        .add(const TogglePrayerMuteStateEvent());
                  },
                  child: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 15.sp,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(2.w, 0, 2.w, 2.h),
              child: Column(
                children: [
                  Expanded(
                    flex: 11,
                    child: Row(
                      children: [
                        _prayerCell(
                          name: translate('home.Fajr'),
                          time: _fmt(_timeFor('fajr')),
                          textColor: _textColor(Prayer.fajr),
                          prayer: Prayer.fajr,
                        ),
                        _prayerCell(
                          name: 'Shuruk',
                          time: _fmt(_timeFor('sunrise')),
                          textColor: Colors.white.withValues(alpha: 0.88),
                        ),
                        _prayerCell(
                          name: translate('home.Dhuhr'),
                          time: _fmt(_timeFor('dhuhr')),
                          textColor: _textColor(Prayer.dhuhr),
                          prayer: Prayer.dhuhr,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 11,
                    child: Row(
                      children: [
                        _prayerCell(
                          name: translate('home.Asr'),
                          time: _fmt(_timeFor('asr')),
                          textColor: _textColor(Prayer.asr),
                          prayer: Prayer.asr,
                        ),
                        _prayerCell(
                          name: translate('home.Maghrib'),
                          time: _fmt(_timeFor('maghrib')),
                          textColor: _textColor(Prayer.maghrib),
                          prayer: Prayer.maghrib,
                        ),
                        _prayerCell(
                          name: translate('home.Isha'),
                          time: _fmt(_timeFor('isha')),
                          textColor: _textColor(Prayer.isha),
                          prayer: Prayer.isha,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 8,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              translate(
                                'home.till_prayer',
                                args: {
                                  'prayer': translate(
                                    _prayerKey(_nextPrayer ?? Prayer.fajr),
                                  ),
                                },
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 9.sp,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            DefaultTextStyle(
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              child: PrayerCountdownTimer(
                                nextPrayerTime: _nextTime,
                              ),
                            ),
                          ],
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
