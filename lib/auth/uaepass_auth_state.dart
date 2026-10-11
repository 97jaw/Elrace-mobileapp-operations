part of 'uaepass_auth_cubit.dart';

enum UaepassAuthStatus {
  idle,
  loading,
  waiting,
  appToApp,
  appToWeb,
  success,
  failure,
}

class UaepassAuthState extends Equatable {
  final UaepassAuthStatus status;
  final AuthFailureType? failureType;

  /// Authorization URL for [UaepassAuthStatus.appToApp] (hidden WebView) or
  /// [UaepassAuthStatus.appToWeb] (in-app web login).
  final Uri? loginUrl;

  const UaepassAuthState._(this.status, this.failureType, [this.loginUrl]);

  const UaepassAuthState.idle() : this._(UaepassAuthStatus.idle, null);

  const UaepassAuthState.loading() : this._(UaepassAuthStatus.loading, null);

  const UaepassAuthState.waiting() : this._(UaepassAuthStatus.waiting, null);

  const UaepassAuthState.appToApp(Uri url)
      : this._(UaepassAuthStatus.appToApp, null, url);

  const UaepassAuthState.appToWeb(Uri url)
      : this._(UaepassAuthStatus.appToWeb, null, url);

  const UaepassAuthState.success() : this._(UaepassAuthStatus.success, null);

  const UaepassAuthState.failure(AuthFailureType? failure)
      : this._(UaepassAuthStatus.failure, failure);

  @override
  List<Object?> get props => [status, failureType, loginUrl];
}
