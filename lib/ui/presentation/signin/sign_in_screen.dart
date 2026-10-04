import 'dart:developer';
import 'dart:math' as math;

import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/core/app_notices/app_notice_gate.dart';
import 'package:el_race/chat/services/chat_credential_storage.dart';
import 'package:el_race/core/config/feature_flags.dart';
import 'package:el_race/core/session/post_login_setup.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/auth/error_dialog.dart';
import 'package:el_race/ui/auth/uaepass_app_to_app_screen.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/signin/bloc/sign_in_bloc.dart';
import 'package:el_race/ui/widgets/login_progress_card.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const double _tabletScale = 1.15;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isPasswordVisible = false;
  late SignInBloc signInBloc;
  bool _isLoadingDialogVisible = false;

  void _showLoadingDialog() {
    if (!mounted || _isLoadingDialogVisible) return;
    _isLoadingDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoginProgressCard(),
    );
  }

  void _hideLoadingDialog() {
    if (!mounted || !_isLoadingDialogVisible) return;
    _isLoadingDialogVisible = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppNoticeGate.atSignIn(context);
    });
  }

  @override
  void didChangeDependencies() {
    signInBloc = SignInBloc.get(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  bool _uaepassInProgress = false;

  Future<T> _withSpinner<T>(Future<T> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      return await task();
    } finally {
      navigator.pop();
    }
  }

  Future<void> _onUaepassPressed() async {
    if (_uaepassInProgress) return;
    _uaepassInProgress = true;
    try {
      await _runUaepassLogin();
    } finally {
      _uaepassInProgress = false;
    }
  }

  Future<void> _runUaepassLogin() async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<UaepassAuthCubit>();

    await _withSpinner(cubit.startLogin);
    if (!mounted) return;
    if (cubit.state.status != UaepassAuthStatus.appToApp ||
        cubit.state.appToAppUrl == null) {
      await ErrorDialog.showForFailure(context, cubit.state.failureType);
      cubit.reset();
      return;
    }

    final result = await Navigator.of(context).push<Uri>(
      MaterialPageRoute(
        builder: (_) => UaepassAppToAppScreen(
          config: cubit.config,
          authorizationUrl: cubit.state.appToAppUrl!,
        ),
      ),
    );
    if (!mounted) return;

    if (result == null) {
      cubit.cancelled();
    } else {
      await _withSpinner(() => cubit.handleCallbackOrResult(result));
    }
    if (!mounted) return;

    if (cubit.state.status != UaepassAuthStatus.success) {
      await ErrorDialog.showForFailure(context, cubit.state.failureType);
      cubit.reset();
      return;
    }

    await PostLoginSetup.applyAfterLogin(context);
    if (!mounted) return;
    if (!await AppNoticeGate.afterLogin(context)) return;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _onLoginPressed() {
    FocusScope.of(context).unfocus();
    final email = usernameController.text.trim();
    final password = passwordController.text;

    final String? error;
    if (email.isEmpty && password.isEmpty) {
      error = 'Please enter your email and password.';
    } else if (email.isEmpty) {
      error = 'Please enter your email.';
    } else if (password.isEmpty) {
      error = 'Please enter your password.';
    } else {
      error = null;
    }

    if (error != null) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Error'),
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    signInBloc.add(SignInET(
      email: email,
      password: password,
      deviceId: '776655',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final tablet = ResponsiveBreakpoints.useTabletLayout(context);
    // Tablet: raw logical pixels with a mild boost — SizeConfig shrinks tablet
    // sizes and screen-width scaling blows up on landscape.
    double vh(double size) =>
        tablet ? size * _tabletScale : SizeConfig().getHeight(size);
    double vsp(double size) =>
        tablet ? size * _tabletScale : SizeConfig().getTextSize(size);
    // Mockup: input fields are wider than the Log in button; button is inset.
    final fieldWidth = tablet
        ? (screenWidth * 0.6).clamp(352.0, 460.0)
        : (screenWidth * 0.82).clamp(280.0, 352.0);
    final loginButtonWidth = fieldWidth * 0.90;
    // "or" divider is shorter than both Log in / UAE PASS buttons.
    final orDividerWidth = loginButtonWidth * 0.72;
    const fieldHeight = 54.0;
    const loginButtonHeight = 48.0;
    // Decorative curves follow the short side on tablet so landscape doesn't
    // stretch them over the form.
    final topCurveWidth =
        tablet ? math.min(screenWidth, screenSize.shortestSide) : screenWidth;
    final bottomCurveWidth =
        tablet ? screenSize.shortestSide * 0.55 : screenWidth * 0.72;

    return BlocConsumer<SignInBloc, SignInState>(
      listener: (context, state) async {
        log('Listener state: $state');

        if (state is ErrMsg) {
          _hideLoadingDialog();
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Error'),
              content: Text(state.msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        if (state is LoadingST) {
          if (state.isLoading) {
            _showLoadingDialog();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _hideLoadingDialog();
            });
          }
        }
        if (state is InitialSignedInST) {
          ChatCredentialStorage.instance.save(
            email: usernameController.text,
            password: passwordController.text,
            deviceId: '776655',
          );

          await PostLoginSetup.applyAfterLogin(context);
          if (!mounted) return;
          _hideLoadingDialog();
          if (!await AppNoticeGate.afterLogin(context)) return;
          if (!mounted) return;

          await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      },
      buildWhen: (previous, current) =>
          current is LoadingST ||
          current is InitialSignedInST ||
          current is ErrMsg,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Image.asset(
                  'assets/png/top_curve.png',
                  width: topCurveWidth,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topLeft,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Image.asset(
                  'assets/png/bottom_curve.png',
                  width: bottomCurveWidth,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: tablet ? 24 : SizeConfig().getWidth(15)),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - vh(56),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/logo/rcc1.png',
                                      fit: BoxFit.contain,
                                      height: vh(64),
                                      width: fieldWidth * 0.92,
                                    ),
                                    SizedBox(height: vh(10)),
                                    Text(
                                      'Log in to your account',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w400,
                                          fontSize: vsp(18)),
                                    ),
                                    SizedBox(height: vh(22)),
                                    SizedBox(
                                      width: fieldWidth,
                                      height: vh(fieldHeight),
                                      child: textForms(
                                        'Email ID',
                                        'account.png',
                                        usernameController,
                                        false,
                                        hintSize: tablet ? 16 : 14,
                                      ),
                                    ),
                                    SizedBox(height: vh(16)),
                                    SizedBox(
                                      width: fieldWidth,
                                      height: vh(fieldHeight),
                                      child: passwordField(
                                          hintSize: tablet ? 16 : 14),
                                    ),
                                    SizedBox(height: vh(16)),
                                    SizedBox(
                                      width: loginButtonWidth,
                                      height: vh(loginButtonHeight),
                                      child: loginButton(_onLoginPressed,
                                          fontSize: vsp(19)),
                                    ),
                                    if (FeatureFlags.showUaepassButton) ...[
                                      SizedBox(height: vh(20)),
                                      SizedBox(
                                        width: orDividerWidth,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: HexColor("#DDDDDD"),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              child: Text(
                                                'or',
                                                style: TextStyle(
                                                  color: HexColor("#999999"),
                                                  fontSize: tablet ? 16 : 14,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: HexColor("#DDDDDD"),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: vh(16)),
                                      SizedBox(
                                        width: loginButtonWidth,
                                        child: _UaepassLoginButton(
                                          onTap: _onUaepassPressed,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: vh(18),
                              top: vh(8),
                            ),
                            child: Text(
                              'Contact with support',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: vsp(17)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget passwordField({required double hintSize}) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: white,
      ),
      child: TextFormField(
        obscureText: !isPasswordVisible,
        controller: passwordController,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
          ),
          hintText: 'Password',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintStyle:
              TextStyle(fontSize: hintSize, color: const Color(0xFF8A8A8A)),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(11),
            child: Image.asset(
              '$imagePrefixIcons/lock.png',
              color: const Color(0xFF8A8A8A),
              width: 18,
              height: 18,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF8A8A8A),
            ),
            onPressed: () {
              setState(() {
                isPasswordVisible = !isPasswordVisible;
              });
            },
          ),
        ),
      ),
    );
  }
}

/// Official UAE PASS button artwork, scaled to width at its native aspect ratio.
class _UaepassLoginButton extends StatelessWidget {
  const _UaepassLoginButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 352 / 60,
          child: Image.asset(
            'assets/png/uaepass_login_button.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

Widget loginButton(Function() onTapped, {required double fontSize}) {
  return GestureDetector(
    onTap: onTapped,
    child: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xffD6D6D6), Color(0xffADB2BD)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Log in',
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

Widget textForms(
    String title, String icon, TextEditingController controller, bool obscure,
    {required double hintSize}) {
  return Container(
    height: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: white,
    ),
    child: TextFormField(
      obscureText: obscure,
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
        ),
        hintText: title,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        hintStyle:
            TextStyle(fontSize: hintSize, color: const Color(0xFF8A8A8A)),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(11),
          child: Image.asset(
            '$imagePrefixIcons/$icon',
            color: const Color(0xFF8A8A8A),
            width: 18,
            height: 18,
          ),
        ),
      ),
    ),
  );
}
