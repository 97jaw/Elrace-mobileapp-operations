part of 'check_in_bloc.dart';

sealed class CheckInEvent extends Equatable {
  const CheckInEvent();
  @override
  List<Object> get props => [];
}

/// Event to trigger check-in (authentication already handled by UI layer)
final class CheckInET extends CheckInEvent {
  const CheckInET({
    this.faceVerified,
    this.faceScore,
    this.livenessOk,
  });

  final bool? faceVerified;
  final double? faceScore;
  final bool? livenessOk;
}
