import 'dart:async';

import 'package:el_race/ui/presentation/attendance_checkin/data/checkin_context_repository.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/services/checkin_geofence_service.dart';
import 'package:el_race/ui/presentation/attendance_checkin/services/checkin_route_service.dart';
import 'package:el_race/ui/presentation/home_screen/repository/location_reop.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CheckinActivityState {
  const CheckinActivityState({
    this.loading = true,
    this.error,
    this.context,
    this.userPosition,
    this.selectedProject,
    this.userManuallySelectedProject = false,
    this.distancePreview,
    this.isInsideGeofence = false,
    this.routePoints = const [],
    this.routeLoading = false,
    this.checkinProjects = const [],
  });

  final bool loading;
  final String? error;
  final CheckinContextModel? context;
  final Position? userPosition;
  final CheckinAllowedProject? selectedProject;
  final bool userManuallySelectedProject;
  final TimesheetGeofencePreview? distancePreview;
  final bool isInsideGeofence;
  final List<LatLng> routePoints;
  final bool routeLoading;
  final List<CheckinAllowedProject> checkinProjects;

  CheckinActivityState copyWith({
    bool? loading,
    String? error,
    CheckinContextModel? context,
    Position? userPosition,
    CheckinAllowedProject? selectedProject,
    bool? userManuallySelectedProject,
    TimesheetGeofencePreview? distancePreview,
    bool? isInsideGeofence,
    List<LatLng>? routePoints,
    bool? routeLoading,
    List<CheckinAllowedProject>? checkinProjects,
    bool clearError = false,
    bool clearSelectedProject = false,
  }) {
    return CheckinActivityState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      context: context ?? this.context,
      userPosition: userPosition ?? this.userPosition,
      selectedProject:
          clearSelectedProject ? null : (selectedProject ?? this.selectedProject),
      userManuallySelectedProject:
          userManuallySelectedProject ?? this.userManuallySelectedProject,
      distancePreview: distancePreview ?? this.distancePreview,
      isInsideGeofence: isInsideGeofence ?? this.isInsideGeofence,
      routePoints: routePoints ?? this.routePoints,
      routeLoading: routeLoading ?? this.routeLoading,
      checkinProjects: checkinProjects ?? this.checkinProjects,
    );
  }
}

class CheckinActivityController extends ChangeNotifier {
  CheckinActivityController({
    CheckinContextRepository? repository,
    LocationRepo? locationRepo,
    CheckinGeofenceService? geofenceService,
    CheckinRouteService? routeService,
  })  : _repository = repository ?? CheckinContextRepository(),
        _locationRepo = locationRepo ?? LocationRepo(),
        _geofence = geofenceService ?? const CheckinGeofenceService(),
        _routeService = routeService ?? const CheckinRouteService();

  final CheckinContextRepository _repository;
  final LocationRepo _locationRepo;
  final CheckinGeofenceService _geofence;
  final CheckinRouteService _routeService;

  CheckinActivityState _state = const CheckinActivityState();
  StreamSubscription<Position>? _positionSub;
  Timer? _routeDebounce;
  int _routeRequestId = 0;
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);

  CheckinActivityState get state => _state;

  Future<void> initialize() async {
    _state = _state.copyWith(loading: true, clearError: true);
    notifyListeners();

    // Start GPS immediately so the map can render without waiting on the API.
    unawaited(_startLocationUpdates());

    try {
      final results = await Future.wait([
        _repository.fetchCheckinContext(),
        _repository.fetchCheckinMapProjects(),
      ]);
      final context = results[0] as CheckinContextModel;
      final checkinProjects = results[1] as List<CheckinAllowedProject>;

      _state = _state.copyWith(
        context: context,
        checkinProjects: checkinProjects,
        loading: false,
      );
      _autoSelectProject();
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> refreshContext() async {
    try {
      final results = await Future.wait([
        _repository.fetchCheckinContext(),
        _repository.fetchCheckinMapProjects(),
      ]);
      final context = results[0] as CheckinContextModel;
      final checkinProjects = results[1] as List<CheckinAllowedProject>;

      _state = _state.copyWith(
        context: context,
        checkinProjects: checkinProjects,
        clearError: true,
      );
      _autoSelectProject();
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> _startLocationUpdates() async {
    await _positionSub?.cancel();

    // Center the map instantly on the cached fix while a fresh one resolves.
    final lastKnown = await _locationRepo.getLastKnownLocation();
    if (lastKnown != null && _state.userPosition == null) {
      _applyUserPosition(lastKnown, forceNotify: true);
    }

    try {
      final initial = await _locationRepo.getCurrentLocation(
        timeLimit: const Duration(seconds: 10),
      );
      _applyUserPosition(initial, forceNotify: true);
    } catch (e) {
      // Only surface the error when we have no location at all; a stale
      // last-known fix is still usable until the stream delivers a fresh one.
      if (_state.userPosition == null) {
        _state = _state.copyWith(error: e.toString());
        notifyListeners();
      }
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      _applyUserPosition,
      onError: (Object e) {
        if (_state.userPosition != null) return;
        _state = _state.copyWith(error: e.toString());
        notifyListeners();
      },
    );
  }

  void _applyUserPosition(Position position, {bool forceNotify = false}) {
    final hadPosition = _state.userPosition != null;
    final wasInside = _state.isInsideGeofence;
    _state = _state.copyWith(userPosition: position, clearError: true);
    if (!_state.userManuallySelectedProject) {
      _autoSelectProject(notify: false);
    } else {
      _updateGeofencePreview(notify: false);
    }
    _scheduleRouteRefresh(notify: false);

    // State (used by geofence/validation) is always fresh; UI rebuilds are
    // throttled so a 5m-interval GPS stream doesn't rebuild the whole screen.
    final now = DateTime.now();
    final geofenceChanged = _state.isInsideGeofence != wasInside;
    if (forceNotify ||
        !hadPosition ||
        geofenceChanged ||
        now.difference(_lastPositionNotify) >= const Duration(seconds: 1)) {
      _lastPositionNotify = now;
      notifyListeners();
    }
  }

  void selectProject(CheckinAllowedProject project) {
    _state = _state.copyWith(
      selectedProject: project,
      userManuallySelectedProject: true,
    );
    _updateGeofencePreview();
    _scheduleRouteRefresh();
    notifyListeners();
  }

  void _autoSelectProject({bool notify = true}) {
    final projects = _state.checkinProjects;
    if (projects.isEmpty) {
      _state = _state.copyWith(clearSelectedProject: true);
      if (notify) notifyListeners();
      return;
    }

    final userPoint = _userGeoPoint;
    final nearest = _geofence.nearestProject(
      userPoint: userPoint,
      projects: projects,
    );
    if (nearest == null) return;

    _state = _state.copyWith(selectedProject: nearest);
    _updateGeofencePreview(notify: false);
    _scheduleRouteRefresh(notify: false);
    if (notify) notifyListeners();
  }

  void _scheduleRouteRefresh({bool notify = true}) {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_refreshRoute(notify: notify));
    });
  }

  Future<void> _refreshRoute({bool notify = true}) async {
    final project = _state.selectedProject;
    final pos = _state.userPosition;
    if (project == null || pos == null) {
      _state = _state.copyWith(routePoints: const [], routeLoading: false);
      if (notify) notifyListeners();
      return;
    }

    final requestId = ++_routeRequestId;
    _state = _state.copyWith(routeLoading: true);
    if (notify) notifyListeners();

    final points = await _routeService.fetchRoute(
      userLat: pos.latitude,
      userLon: pos.longitude,
      destLat: project.lat,
      destLon: project.lng,
    );

    if (requestId != _routeRequestId) return;
    _state = _state.copyWith(routePoints: points, routeLoading: false);
    if (notify) notifyListeners();
  }

  void _updateGeofencePreview({bool notify = true}) {
    final project = _state.selectedProject;
    if (project == null) {
      _state = _state.copyWith(
        distancePreview: null,
        isInsideGeofence: false,
      );
      if (notify) notifyListeners();
      return;
    }

    final preview = _geofence.preview(
      userPoint: _userGeoPoint,
      project: project,
    );
    _state = _state.copyWith(
      distancePreview: preview,
      isInsideGeofence: preview.isInside,
    );
    _scheduleRouteRefresh(notify: false);
    if (notify) notifyListeners();
  }

  TimesheetGeoPoint? get _userGeoPoint {
    final pos = _state.userPosition;
    if (pos == null) return null;
    return TimesheetGeoPoint(lat: pos.latitude, lon: pos.longitude);
  }

  Future<bool> validateSelectedProjectLocation() async {
    final project = _state.selectedProject;
    final pos = _state.userPosition;
    if (project == null) {
      _state = _state.copyWith(error: 'Select a project before check-in.');
      notifyListeners();
      return false;
    }
    if (pos == null) {
      _state = _state.copyWith(error: 'Waiting for GPS location.');
      notifyListeners();
      return false;
    }

    try {
      final result = await _repository.validateUserLocation(
        projectId: project.projectId,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (result['status'] == 'success') {
        _state = _state.copyWith(clearError: true);
        notifyListeners();
        return true;
      }
      _state = _state.copyWith(
        error: result['message']?.toString() ??
            'You are not within the project location.',
      );
      notifyListeners();
      return false;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
