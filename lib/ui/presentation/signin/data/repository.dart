import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginUnreachableException implements Exception {
  const LoginUnreachableException();

  @override
  String toString() =>
      'Could not reach the server. Check your connection and try again.';
}

class UserRepo {
  static const String _loginDb = 'odoo.elrace.com';

  ApiQuery apiQuery = ApiQuery();

  Future<Response> loginApiCall(
      String email, String password, String deviceId) async {
    print('\n🔐 ========== LOGIN API START ==========');
    print('📧 Email: $email');
    print('🔒 Password: ${password.replaceAll(RegExp(r'.'), '*')}');
    print('📱 Device ID: $deviceId');

    // Get FCM token from SharedPreferences
    String? fcmToken = SharedPref().getPreferenceString(fcm_token);

    // If FCM token is null or empty, log a warning
    if (fcmToken.isEmpty) {
      print('⚠️ Warning: FCM token is empty during login');
    } else {
      print('✅ FCM token available: ${fcmToken.substring(0, 20)}...');
    }

    final headers = {
      'Content-Type': 'application/json',
    };
    // One request only: every failed attempt counts toward Odoo's login
    // cooldown, and retrying other paths/dbs hides the real error.
    final body = {
      "jsonrpc": "2.0",
      "params": {
        "db": _loginDb,
        "login": email,
        "password": password,
        "device_id": deviceId,
        "fcm_token": fcmToken,
      }
    };
    print('\n⏳ Sending login request to: ${UrlUtil.baseUrl}${UrlUtil.login}');

    Response? response;
    for (var attempt = 0; attempt < 2 && response == null; attempt++) {
      response =
          await apiQuery.postQuery(UrlUtil.login, headers, body, 'login', true);
    }
    if (response == null) throw const LoginUnreachableException();

    print('\n📥 Login Response Status: ${response.statusCode}');
    print('📦 Response Data Type: ${response.data.runtimeType}');

    if (response.data != null) {
      print('📄 Full Login Response:');
      print(const JsonEncoder.withIndent('  ').convert(response.data));

      // Parse and display important data
      try {
        final data = response.data;
        if (data['result'] != null) {
          final result = data['result'];
          print('\n✅ Login Successful!');
          print('🔑 Token: ${result['token']?.toString().substring(0, 30)}...');

          if (result['data'] != null) {
            final userData = result['data'];
            print('\n👤 User Data:');
            print('  - Employee ID: ${userData['emp_id']}');
            print('  - Employee Profile ID: ${userData['emp_profile_id']}');
            print('  - Name: ${userData['name']}');
            print('  - Username: ${userData['username']}');
            print('  - Company ID: ${userData['company_id']}');
            print('  - QR Status: ${userData['qr_status']}');
          }
        } else if (data['error'] != null) {
          print('\n❌ Login Failed!');
          print('Error: ${data['error']}');
        }
      } catch (e) {
        print('⚠️ Could not parse login response: $e');
      }
    } else {
      print('❌ No response data received');
    }

    print('🔐 ========== LOGIN API END ==========\n');

    return response;
  }

  setLoginResponse(
    LoginResponseModel? loginResponse, {
    Map<String, dynamic>? rawJson,
  }) async {
    if (loginResponse != null) {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      final payload = rawJson ?? loginResponse.toJson();
      await sharedPreferences.setString('loginResponse', json.encode(payload));
    }
  }

  Future<LoginResponseModel?> getLoginResponse() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    String? userData = sharedPreferences.getString('loginResponse');

    if (userData == null) {
      // print('⚠️ No login data found in SharedPreferences');
      return null;
    }

    // print('\n📖 Retrieved login data from SharedPreferences');
    final loginData = LoginResponseModel.fromJson(jsonDecode(userData));

    // print('👤 Current User:');
    // print('  - Employee ID: ${loginData.result?.data?.emp_id}');
    // print('  - Employee Profile ID: ${loginData.result?.data?.emp_profile_id}');
    // print('  - Token: ${loginData.result?.token?.substring(0, 30)}...');
    // print('  - QR Status: ${loginData.result?.data?.qr_status}');

    return loginData;
  }

  setISLoggedIn(bool isLoggedIn) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.setBool(isLoggedIN, isLoggedIn);
  }

  Future<bool?> getIsLoggedIn() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(isLoggedIN) ?? false;
  }

  setDeviceInfo(String deviceInfo) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.setString(deviceInfoString, deviceInfo);
  }

  Future<String?> getDeviceInfo() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(deviceInfoString) ?? '';
  }
}
