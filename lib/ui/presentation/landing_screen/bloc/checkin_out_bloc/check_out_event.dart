part of 'check_out_bloc.dart';

sealed class CheckOutEvent extends Equatable {
  const CheckOutEvent();

  @override
  List<Object> get props => [];
}

final class CheckOutET extends CheckOutEvent {
  final int checkInRecordId;
  final bool isAutoCheckout; // true = scheduled auto checkout, false = manual
  final bool? faceVerified;
  final double? faceScore;
  final bool? livenessOk;

  const CheckOutET(
    this.checkInRecordId, {
    this.isAutoCheckout = false,
    this.faceVerified,
    this.faceScore,
    this.livenessOk,
  });

  @override
  List<Object> get props => [
        checkInRecordId,
        isAutoCheckout,
        faceVerified ?? false,
        faceScore ?? -1.0,
        livenessOk ?? false,
      ];
}
