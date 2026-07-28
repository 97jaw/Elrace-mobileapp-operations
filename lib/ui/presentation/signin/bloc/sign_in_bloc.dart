import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../firebase_service.dart';
import '../../../../utils/di.dart';

part 'sign_in_event.dart';
part 'sign_in_state.dart';

final userRepo = sl.get<UserRepo>();
var loginResponseModel = sl.get<LoginResponseModel>();

class SignInBloc extends Bloc<SignInEvent, SignInState> {
  static SignInBloc get(BuildContext context) => BlocProvider.of(context);

  SignInBloc() : super(SignInInitial()) {
    on<CheckSignedIn>(checkSignInMethod);
    on<SignInET>(signInMethod);
  }

  /// Returns a persistent unique device ID per user (email).
  /// Generated once and stored in SecureStorage so it never changes.
  Future<String> _getOrCreateDeviceId(String email) async {
    const storage = FlutterSecureStorage();
    final key = 'device_id_${email.toLowerCase().trim()}';
    final existing = await storage.read(key: key);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = const Uuid().v4();
    await storage.write(key: key, value: newId);
    return newId;
  }

  FutureOr<void> signInMethod(SignInET event, Emitter<SignInState> emit) async {
    emit(const LoadingST(isLoading: true));

    await FirebaseService.ensureFCMToken();

    // Unique, persistent device ID per user
    final deviceName = await _getOrCreateDeviceId(event.email);
    log('device_id: $deviceName');

    try {
      Response response =
          await userRepo.loginApiCall(event.email, event.password, deviceName);
      if (response.statusCode == 200) {
        final raw = response.data;
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is! Map) {
          throw Exception(
              'Unexpected login payload type: ${decoded.runtimeType}');
        }
        final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
        loginResponseModel = LoginResponseModel.fromJson(json);

        await userRepo.setDeviceInfo(deviceName);

        if (loginResponseModel.result?.success == true) {
          await userRepo.setLoginResponse(loginResponseModel, rawJson: json);
          await userRepo.setISLoggedIn(true);
          await SharedPref().setPreferencesBoolean('isRegistered', true);
          // Update login state in Hive for background service
          await HiveService.setUserLoggedIn(true);
          // Login JWT is ready — push FCM token (may have been empty at request time).
          unawaited(() async {
            await FirebaseService.ensureFCMToken();
            await FirebaseService.syncFcmTokenToOdoo(force: true);
          }());
          emit(InitialSignedInST(loginResponse: loginResponseModel));
          emit(const LoadingST(isLoading: false));
        } else {
          final message = loginResponseModel.result?.message ??
              'Login failed. Please try again.';
          emit(ErrMsg(msg: message));
          emit(const LoadingST(isLoading: false));
        }
      } else {
        throw Exception('Login HTTP ${response.statusCode}');
      }
    } catch (e) {
      log('signInMethod error: $e');
      emit(ErrMsg(msg: e.toString()));
      emit(const LoadingST(isLoading: false));
    }
  }

  FutureOr<void> checkSignInMethod(
      CheckSignedIn event, Emitter<SignInState> emit) async {
    final isSignedIn = await userRepo.getIsLoggedIn();

    log('isSignedIn $isSignedIn');
    // if (isSignedIn!) {
    final loginResponse = await userRepo.getLoginResponse();
    emit(InitialSignedInST(loginResponse: loginResponse!));
    // } else {
    //   emit(NotSignedInST());
    // }
    try {} catch (e) {
      log('checkSignInMethod $e');
    }
  }
}
