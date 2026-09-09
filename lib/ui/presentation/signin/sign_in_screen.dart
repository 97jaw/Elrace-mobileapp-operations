import 'dart:developer';

import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/chat/services/chat_credential_storage.dart';
import 'package:el_race/core/config/feature_flags.dart';
import 'package:el_race/core/session/post_login_setup.dart';
import 'package:el_race/ui/auth/auth_loading_screen.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/signin/bloc/sign_in_bloc.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
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
      builder: (_) => const Center(child: CircularProgressIndicator()),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

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
                right: 0,
                child: Image.asset(
                  'assets/png/top_curve.png',
                  width: screenWidth,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Image.asset(
                  'assets/png/bottom_curve.png',
                  width: screenWidth * 0.72,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig().getWidth(15)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: SizeConfig().getHeight(110),
                        ),
                        Image.asset(
                          'assets/gif/el-race-logo.gif',
                          fit: BoxFit.contain,
                          height: SizeConfig().getHeight(120),
                        ),
                        Text(
                          'Sign in to your account',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              fontSize: SizeConfig().getTextSize(20)),
                        ),
                        SizedBox(height: SizeConfig().getHeight(20)),
                        textForms('Email ID', 'account.png', usernameController,
                            false),
                        SizedBox(height: SizeConfig().getHeight(40)),
                        passwordField(),
                        SizedBox(height: SizeConfig().getHeight(30)),
                        SizedBox(
                          width: 227,
                          child: loginButton(() {
                            signInBloc.add(SignInET(
                              email: usernameController.text,
                              password: passwordController.text,
                              deviceId: '776655',
                            ));
                          }),
                        ),
                        if (FeatureFlags.showUaepassButton) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 227,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: HexColor("#DDDDDD"),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      color: HexColor("#999999"),
                                      fontSize: 14.0,
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
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 227,
                            child: GestureDetector(
                              onTap: () {
                                final uaepassCubit =
                                    context.read<UaepassAuthCubit>();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AuthLoadingScreen(),
                                  ),
                                );
                                uaepassCubit.startLogin();
                              },
                              child: Image.asset(
                                'assets/newapp/uae-pass-button.png',
                                width: 227,
                                fit: BoxFit.contain,
                                errorBuilder: (context, _, __) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: const Text('Sign in with UAE PASS'),
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: SizeConfig().getHeight(70)),
                        Text(
                          'Contact support',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: SizeConfig().getTextSize(18)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget passwordField() {
    return Container(
      height: SizeConfig().getHeight(55),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(52),
        color: white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.2 * 255).toInt()),
            blurRadius: 12,
          )
        ],
      ),
      child: TextFormField(
        obscureText: !isPasswordVisible,
        controller: passwordController,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Password',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF545454)),
          prefixIcon: Image.asset(
            '$imagePrefixIcons/lock.png',
            color: const Color(0xFF545454),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF545454),
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

Widget loginButton(Function() onTapped) {
  return GestureDetector(
    onTap: onTapped,
    child: Container(
      width: double.infinity,
      height: SizeConfig().getHeight(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xffD6D6D6), Color(0xffADB2BD)]),
        borderRadius: BorderRadius.circular(54),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Log in',
              style: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig().getTextSize(19),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: SizeConfig().getWidth(8)),
            const Icon(Icons.arrow_forward, color: Colors.black),
          ],
        ),
      ),
    ),
  );
}

Widget textForms(
    String title, String icon, TextEditingController controller, bool obscure) {
  return Container(
    height: SizeConfig().getHeight(55),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(52),
      color: white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((0.2 * 255).toInt()),
          blurRadius: 12,
        )
      ],
    ),
    child: TextFormField(
      obscureText: obscure,
      controller: controller,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: title,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF545454)),
        prefixIcon: Image.asset(
          '$imagePrefixIcons/$icon',
          color: const Color(0xFF545454),
        ),
      ),
    ),
  );
}
