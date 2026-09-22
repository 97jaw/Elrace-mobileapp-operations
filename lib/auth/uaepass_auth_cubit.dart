import 'package:bloc/bloc.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/services/uaepass_auth_service.dart';
import 'package:el_race/ui/auth/error_dialog.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:equatable/equatable.dart';

part 'uaepass_auth_state.dart';

class UaepassAuthCubit extends Cubit<UaepassAuthState> {
  final UaepassAuthService authService;
  final UaepassConfig config;

  UaepassAuthCubit({required this.authService, required this.config})
      : super(const UaepassAuthState.idle());

  Future<void> startLogin() async {
    UaepassLogger.log('Cubit: startLogin called');
    emit(const UaepassAuthState.loading());
    try {
      await authService.startLogin();
      UaepassLogger.log('Cubit: Emitting waiting state (browser opened)');
      emit(const UaepassAuthState.waiting());
    } catch (e) {
      UaepassLogger.logError('Cubit: startLogin failed', e);
      emit(const UaepassAuthState.failure(AuthFailureType.generic));
    }
  }

  Future<void> handleCallbackOrResult(Uri uri) async {
    UaepassLogger.log('Cubit: handleCallbackOrResult called');
    if (state.status == UaepassAuthStatus.loading) {
      UaepassLogger.logWarning('Cubit: callback ignored — exchange already in progress');
      return;
    }
    emit(const UaepassAuthState.loading());
    final result = await authService.handleCallbackOrResult(uri);
    if (result.isSuccess) {
      UaepassLogger.logSuccess('Cubit: Emitting success state');
      emit(const UaepassAuthState.success());
    } else {
      final msg = messageFor(result.failureType);
      UaepassLogger.logError('Cubit: Emitting failure state');
      UaepassLogger.logKV('Failure type', result.failureType?.toString());
      UaepassLogger.logKV('UI Message', msg);
      emit(UaepassAuthState.failure(result.failureType));
    }
  }

  /// Called when user taps "I have approved in UAE PASS" button
  /// 
  /// This tries to finalize the login by:
  /// 1. Checking for any stored session/tx from a deep link that was received
  /// 2. If polling is enabled, polls the backend for result
  /// 3. If nothing works, shows a generic error
  Future<void> tryFinalizeLogin() async {
    UaepassLogger.logSection('TRY FINALIZE LOGIN (from button)');
    UaepassLogger.log('Cubit: tryFinalizeLogin called');

    if (state.status == UaepassAuthStatus.loading) {
      UaepassLogger.logWarning('Cubit: finalize ignored — exchange already in progress');
      return;
    }

    emit(const UaepassAuthState.loading());
    
    try {
      final result = await authService.tryFinalizeFromStoredData();
      
      if (result.isSuccess) {
        UaepassLogger.logSuccess('Cubit: Login finalized successfully');
        emit(const UaepassAuthState.success());
      } else {
        final msg = messageFor(result.failureType);
        UaepassLogger.logError('Cubit: Finalization failed');
        UaepassLogger.logKV('Failure type', result.failureType?.toString());
        UaepassLogger.logKV('UI Message', msg);
        emit(UaepassAuthState.failure(result.failureType));
      }
    } catch (e) {
      UaepassLogger.logError('Cubit: tryFinalizeLogin exception', e);
      emit(const UaepassAuthState.failure(AuthFailureType.generic));
    }
  }

  Future<void> logout() async {
    UaepassLogger.log('Cubit: logout called');
    await authService.logout();
    UaepassLogger.log('Cubit: Emitting idle state after logout');
    emit(const UaepassAuthState.idle());
  }

  void reset() {
    UaepassLogger.log('Cubit: reset called');
    emit(const UaepassAuthState.idle());
  }

  String messageFor(AuthFailureType? type) => ErrorDialog.messageFor(type);
}
