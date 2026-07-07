import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:flutter/material.dart';

/// Portfolio health bucket for map filters and marker styling.
enum PortfolioProjectBucket {
  all,
  onTrack,
  unTrack,
}

/// Accent for map pins, chips, and priority cards.
extension PortfolioProjectBucketMapStyle on PortfolioProjectBucket {
  Color get mapAccentColor {
    switch (this) {
      case PortfolioProjectBucket.all:
        return const Color(0xFF1565C0);
      case PortfolioProjectBucket.onTrack:
        return const Color(0xFF2E7D32);
      case PortfolioProjectBucket.unTrack:
        return const Color(0xFFEF6C00);
    }
  }
}

extension PortfolioProjectBucketX on PortfolioProjectBucket {
  String get label {
    switch (this) {
      case PortfolioProjectBucket.all:
        return 'All';
      case PortfolioProjectBucket.onTrack:
        return 'On track';
      case PortfolioProjectBucket.unTrack:
        return 'Un track';
    }
  }
}

bool hasRealCoordinates(ProjectEntity p) {
  final lat = p.latitude;
  final lng = p.longitude;
  if (lat == null || lng == null) return false;
  if (lat.abs() < 1e-6 || lng.abs() < 1e-6) return false; // zero values
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/// Classifies a project by coordinate availability:
/// onTrack = has real coordinates, unTrack = no coordinates.
PortfolioProjectBucket classifyProjectBucket(ProjectEntity p) {
  return hasRealCoordinates(p)
      ? PortfolioProjectBucket.onTrack
      : PortfolioProjectBucket.unTrack;
}

bool projectMatchesBucket(ProjectEntity p, PortfolioProjectBucket filter) {
  if (filter == PortfolioProjectBucket.all) return true;
  return classifyProjectBucket(p) == filter;
}
