import 'package:app_links/app_links.dart';
import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/core/session/post_login_setup.dart';
import 'package:el_race/deep_links/uaepass_link_handler.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/auth/error_dialog.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// UAE PASS "Waiting / Return to app" Screen
///
/// Shown after the browser opens for UAE PASS authentication.
class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({super.key});

  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen>
    with WidgetsBindingObserver {
  bool _isRetrying = false;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingUaePassLink();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingUaePassLink();
    }
  }

  /// iOS often delivers elrace://uaepass/success?session=... on resume, not on
  /// manual app switch — pick up the pending link here.
  Future<void> _checkPendingUaePassLink() async {
    try {
      final uri = await _appLinks.getLatestLink();
      if (uri == null) return;
      UaepassLogger.log('AuthLoadingScreen: pending link on resume: $uri');
      if (!mounted) return;
      await UaepassLinkHandler.handle(uri);
    } catch (e) {
      UaepassLogger.logError('AuthLoadingScreen: link check failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UaepassAuthCubit>();
    final config = cubit.config;

    return BlocListener<UaepassAuthCubit, UaepassAuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        UaepassLogger.logKV('AuthLoadingScreen state', state.status.toString());

        if (state.status == UaepassAuthStatus.success) {
          UaepassLogger.logSuccess('Navigating to Dashboard');
          if (context.mounted) {
            await PostLoginSetup.applyAfterLogin(context);
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
          return;
        }

        if (state.status == UaepassAuthStatus.failure) {
          final message = cubit.messageFor(state.failureType);
          UaepassLogger.logError('Login failed', message);
          if (context.mounted) {
            await ErrorDialog.showForFailure(context, state.failureType);
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () {
              UaepassLogger.log('User closed waiting screen');
              cubit.reset();
              Navigator.of(context).pop();
            },
          ),
          title: const Text(
            'Complete UAE PASS Login',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: BlocBuilder<UaepassAuthCubit, UaepassAuthState>(
            builder: (context, state) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A3E0).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          size: 40,
                          color: Color(0xFF00A3E0),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (state.status == UaepassAuthStatus.loading ||
                          _isRetrying) ...[
                        const CircularProgressIndicator(
                          color: Color(0xFF00A3E0),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRetrying
                              ? 'Checking login status...'
                              : config.loadingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      if (state.status == UaepassAuthStatus.waiting &&
                          !_isRetrying) ...[
                        const Text(
                          'Approve the request in UAE PASS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'After approval, tap Open Elrace on the UAE PASS confirmation screen. If you already approved, tap the button below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _tryFinalizeLogin(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A3E0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'I have approved in UAE PASS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            UaepassLogger.log('User cancelled from waiting screen');
                            cubit.reset();
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      if (state.status == UaepassAuthStatus.idle) ...[
                        const Text(
                          'Session expired',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _tryFinalizeLogin(BuildContext context) async {
    UaepassLogger.logSection('TRY FINALIZE LOGIN');
    UaepassLogger.log('User pressed "I have approved" button');

    setState(() => _isRetrying = true);

    // Re-check deep link right before finalize (iOS may have delivered it).
    await _checkPendingUaePassLink();

    final cubit = context.read<UaepassAuthCubit>();
    await cubit.tryFinalizeLogin();

    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }
}
