import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_rejected_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/approval_bloc.dart';
import '../bloc/approval_event.dart';
import '../bloc/approval_state.dart';

class ApprovalActionButtons extends StatelessWidget {
  final String requestId;
  final String type;
  final void Function(String result)? onResult;
  /// Called when server says record is rejected / needs restart validation.
  final VoidCallback? onRejectedLocked;
  final bool disabled;
  final String? selectedAction;
  final List<String> userIds;
  final ApprovalActionButtonsVariant variant;
  final double? pillWidth;
  final double? pillHeight;
  final BorderRadius? pillBorderRadius;
  final TextStyle? pillTextStyle;
  final double? pillSpacing;
  final bool showHrApproveConfirmation;
  final bool enableFakeApproveDemo;
  final bool useProvidedComment;
  final String? Function()? commentProvider;

  const ApprovalActionButtons({
    super.key,
    required this.requestId,
    required this.type,
    this.onResult,
    this.onRejectedLocked,
    this.disabled = false,
    this.selectedAction,
    required this.userIds,
    this.variant = ApprovalActionButtonsVariant.holdCircle,
    this.pillWidth,
    this.pillHeight,
    this.pillBorderRadius,
    this.pillTextStyle,
    this.pillSpacing,
    this.showHrApproveConfirmation = false,
    this.enableFakeApproveDemo = false,
    this.useProvidedComment = false,
    this.commentProvider,
  });

  Future<void> _showOutcomePopup(
    BuildContext context, {
    required String message,
    required bool isSuccess,
  }) async {
    if (!context.mounted) return;
    final isWarning = ApprovalRejectedBanner.messageLooksRejected(message);
    if (!isSuccess && isWarning) {
      onRejectedLocked?.call();
    }
    await showApprovalMessagePopup(
      context,
      message: message,
      isSuccess: isSuccess,
      isWarning: isWarning,
    );
  }

  String _resolveProvidedComment() {
    final raw = commentProvider?.call() ?? '';
    final trimmed = raw.trim();
    return trimmed.isEmpty ? '..' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController commentController = TextEditingController();
    if (variant == ApprovalActionButtonsVariant.rectangle) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildRectangleActionButton(
              context,
              label: 'REJECT',
              color: const Color(0xFFBA1719),
              commentController: commentController,
              isSelected: selectedAction == 'reject',
              listenToBloc: true,
            ),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: _buildRectangleActionButton(
              context,
              label: 'APPROVE',
              color: const Color(0xFF009859),
              commentController: commentController,
              isSelected: selectedAction == 'approve',
              listenToBloc: false,
            ),
          ),
        ],
      );
    }
    if (variant == ApprovalActionButtonsVariant.glass) {
      return Row(
        children: [
          Expanded(
            child: _buildGlassActionButton(
              context,
              label: 'Reject',
              actionLabel: 'REJECT',
              color: const Color(0xFFC62828),
              icon: Icons.close_rounded,
              commentController: commentController,
              listenToBloc: true,
            ),
          ),
          SizedBox(width: 10.tw),
          Expanded(
            child: _buildGlassActionButton(
              context,
              label: 'Approve',
              actionLabel: 'APPROVE',
              color: const Color(0xFF1B8A4E),
              icon: Icons.check_rounded,
              commentController: commentController,
              listenToBloc: false,
            ),
          ),
        ],
      );
    }
    if (variant == ApprovalActionButtonsVariant.pill) {
      return Row(
        children: [
          Expanded(
            child: _buildPillActionButton(
              context,
              label: 'REJECT',
              color: const Color(0xFFBA1719),
              commentController: commentController,
              isSelected: selectedAction == 'reject',
              listenToBloc: true,
              expand: pillWidth == null,
            ),
          ),
          SizedBox(width: pillSpacing ?? 12.tw),
          Expanded(
            child: _buildPillActionButton(
              context,
              label: 'APPROVE',
              color: const Color(0xFF009859),
              commentController: commentController,
              isSelected: selectedAction == 'approve',
              listenToBloc: false,
              expand: pillWidth == null,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320.tw;
        final gap = compact ? 16.tw : 24.tw;
        return Row(
          children: [
            Expanded(
              child: _buildCircleActionButton(
                context,
                'REJECT',
                const Color(0xFFBA1719),
                Icons.close,
                commentController,
                isSelected: selectedAction == 'reject',
                listenToBloc: true,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildCircleActionButton(
                context,
                'APPROVE',
                const Color(0xFF009859),
                Icons.check,
                commentController,
                isSelected: selectedAction == 'approve',
                listenToBloc: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRectangleActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required TextEditingController commentController,
    bool isSelected = false,
    bool listenToBloc = true,
  }) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          if (onResult != null) {
            onResult!(state.message);
          }

          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                _showOutcomePopup(
                  context,
                  message: state.message,
                  isSuccess: true,
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (context.mounted) {
            _showOutcomePopup(
              context,
              message: state.error,
              isSuccess: false,
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        return SizedBox(
          width: double.infinity,
          height: 52.tw,
          child: ElevatedButton(
            onPressed: isButtonDisabled
                ? null
                : () async {
                    final token = SharedPref.getLoginData().result?.token ?? '';
                    String finalComment = '..';
                    if (useProvidedComment) {
                      finalComment = _resolveProvidedComment();
                    } else {
                      final String? comment =
                          await _showCommentDialog(context, label);

                      if (!context.mounted) return;
                      if (comment == null) {
                        return;
                      }
                      finalComment = comment;
                    }

                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: Colors.black54,
                        builder: (BuildContext dialogContext) {
                          return PopScope(
                            canPop: false,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    if (label == 'APPROVE') {
                      context.read<ApprovalBloc>().add(
                            ApproveRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    } else {
                      context.read<ApprovalBloc>().add(
                            RejectRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.tr),
              ),
              elevation: isSelected ? 6 : 2,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 20.tsp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPillActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required TextEditingController commentController,
    bool isSelected = false,
    bool listenToBloc = true,
    bool expand = false,
  }) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          if (onResult != null) {
            onResult!(state.message);
          }

          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                _showOutcomePopup(
                  context,
                  message: state.message,
                  isSuccess: true,
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (context.mounted) {
            _showOutcomePopup(
              context,
              message: state.error,
              isSuccess: false,
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        return SizedBox(
          width: expand ? double.infinity : (pillWidth ?? 150.tw),
          height: pillHeight ?? 52.tw,
          child: ElevatedButton(
            onPressed: isButtonDisabled
                ? null
                : () async {
                    final token = SharedPref.getLoginData().result?.token ?? '';
                    String finalComment = '..';

                    if (useProvidedComment && !showHrApproveConfirmation) {
                      finalComment = _resolveProvidedComment();
                    } else if (showHrApproveConfirmation) {
                      final decision =
                          await _showHrActionSliderDialog(context, label);
                      if (!context.mounted ||
                          decision == null ||
                          !decision.isConfirmed) {
                        return;
                      }

                      if (useProvidedComment) {
                        finalComment = _resolveProvidedComment();
                      } else {
                        finalComment = decision.comment.trim().isEmpty
                            ? '..'
                            : decision.comment.trim();
                      }

                      if (enableFakeApproveDemo) {
                        await _simulateFakeActionSuccess(
                          context,
                          actionLabel: label,
                        );
                        return;
                      }
                    } else {
                      final String? comment =
                          await _showCommentDialog(context, label);

                      if (!context.mounted) return;
                      if (comment == null) {
                        return;
                      }
                      finalComment = comment;
                    }

                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: Colors.black54,
                        builder: (BuildContext dialogContext) {
                          return PopScope(
                            canPop: false,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    if (label == 'APPROVE') {
                      context.read<ApprovalBloc>().add(
                            ApproveRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    } else {
                      context.read<ApprovalBloc>().add(
                            RejectRequest(
                              requestId: requestId,
                              type: type,
                              token: token,
                              userIds: userIds,
                              comment: finalComment,
                            ),
                          );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.4),
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: pillBorderRadius ?? BorderRadius.circular(30),
              ),
            ),
            child: Text(
              '${label.substring(0, 1)}${label.substring(1).toLowerCase()}',
              style: pillTextStyle ??
                  GoogleFonts.poppins(
                    fontSize: 18.tsp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _simulateFakeActionSuccess(
    BuildContext context, {
    required String actionLabel,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 900));

    if (!context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final isApprove = actionLabel == 'APPROVE';
    final fakeMessage = isApprove
        ? 'Approved successfully (demo mode)'
        : 'Rejected successfully (demo mode)';

    if (!context.mounted) return;
    if (onResult != null) {
      onResult!(fakeMessage);
    }

    await showApprovalMessagePopup(
      context,
      message: fakeMessage,
      isSuccess: isApprove,
    );

    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  Future<_ApprovalDialogDecision?> _showHrActionSliderDialog(
    BuildContext context,
    String actionLabel,
  ) async {
    final actionText = actionLabel.toLowerCase();
    final demoComment = actionLabel == 'APPROVE'
        ? 'Fake approval comment'
        : 'Fake rejection comment';

    final TextEditingController commentController = TextEditingController(
      text: enableFakeApproveDemo ? demoComment : '',
    );

    return showDialog<_ApprovalDialogDecision>(
      context: context,
      barrierDismissible: false,
      barrierColor: ApprovalsOverviewTheme.screenDeep.withValues(alpha: 0.35),
      builder: (dialogContext) {
        double sliderProgress = 0.5;
        final isApprove = actionLabel == 'APPROVE';
        final accent = isApprove
            ? const Color(0xFF009859)
            : ApprovalsOverviewTheme.hr;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  EdgeInsets.symmetric(horizontal: 22.tw, vertical: 24.th),
              child: OverviewGlassPanel(
                fillAlpha: 0.96,
                blurSigma: 12,
                radius: 22,
                padding: EdgeInsets.fromLTRB(18.tw, 18.th, 18.tw, 16.th),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44.tw,
                      height: 44.tw,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isApprove
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        color: accent,
                        size: 24.tsp,
                      ),
                    ),
                    SizedBox(height: 12.th),
                    Text(
                      isApprove ? 'Confirm Approval' : 'Confirm Rejection',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16.tsp,
                        fontWeight: FontWeight.w700,
                        color: ApprovalsOverviewTheme.textDark,
                      ),
                    ),
                    SizedBox(height: 6.th),
                    Text(
                      'Are you sure you want to $actionText this invoice?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        fontWeight: FontWeight.w500,
                        color: ApprovalsOverviewTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 16.th),
                    Row(
                      children: [
                        Text(
                          'Comments',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w600,
                            color: ApprovalsOverviewTheme.textDark,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${commentController.text.length}/50',
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            fontWeight: FontWeight.w500,
                            color: ApprovalsOverviewTheme.textSoft,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.th),
                    TextField(
                      controller: commentController,
                      maxLength: 50,
                      onChanged: (_) => setModalState(() {}),
                      minLines: 2,
                      maxLines: 3,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w500,
                        color: ApprovalsOverviewTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write your comment...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          color: ApprovalsOverviewTheme.textSoft,
                        ),
                        filled: true,
                        fillColor: ApprovalsOverviewTheme.screenTintLight
                            .withValues(alpha: 0.85),
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.tw, vertical: 10.th),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.tr),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.tr),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.tr),
                          borderSide: BorderSide(
                            color: ApprovalsOverviewTheme.screenMid
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.th),
                    SizedBox(
                      height: 52.th,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final knobSize = 42.tw;
                          final maxLeft = constraints.maxWidth - knobSize;
                          final knobLeft =
                              (maxLeft * sliderProgress).clamp(0.0, maxLeft);

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 42.th,
                                padding:
                                    EdgeInsets.symmetric(horizontal: 20.tw),
                                decoration: BoxDecoration(
                                  color: ApprovalsOverviewTheme.screenTintLight
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(22.tr),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(dialogContext).pop(
                                          _ApprovalDialogDecision(
                                            isConfirmed: false,
                                            comment: commentController.text,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'No',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.tsp,
                                          fontWeight: FontWeight.w700,
                                          color: ApprovalsOverviewTheme.hr,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(dialogContext).pop(
                                          _ApprovalDialogDecision(
                                            isConfirmed: true,
                                            comment: commentController.text,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Yes',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.tsp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF009859),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: knobLeft,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate: (details) {
                                    final delta = details.primaryDelta ?? 0;
                                    final next = sliderProgress +
                                        (delta /
                                            constraints.maxWidth
                                                .clamp(1.0, double.infinity));
                                    setModalState(() {
                                      sliderProgress = next.clamp(0.0, 1.0);
                                    });
                                  },
                                  onHorizontalDragEnd: (_) {
                                    if (sliderProgress >= 0.82) {
                                      Navigator.of(dialogContext).pop(
                                        _ApprovalDialogDecision(
                                          isConfirmed: true,
                                          comment: commentController.text,
                                        ),
                                      );
                                      return;
                                    }

                                    if (sliderProgress <= 0.18) {
                                      Navigator.of(dialogContext).pop(
                                        _ApprovalDialogDecision(
                                          isConfirmed: false,
                                          comment: commentController.text,
                                        ),
                                      );
                                      return;
                                    }

                                    setModalState(() {
                                      sliderProgress = 0.5;
                                    });
                                  },
                                  child: Container(
                                    width: knobSize,
                                    height: knobSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          ApprovalsOverviewTheme.screenLight,
                                          ApprovalsOverviewTheme.screenDeep,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ApprovalsOverviewTheme.screenDeep
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: Colors.white,
                                      size: 18.tsp,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 8.th),
                    Text(
                      'Slide right to confirm · left to cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 10.tsp,
                        fontWeight: FontWeight.w500,
                        color: ApprovalsOverviewTheme.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        commentController.dispose();
      });
    });
  }

  Widget _buildGlassActionButton(
    BuildContext context, {
    required String label,
    required String actionLabel,
    required Color color,
    required IconData icon,
    required TextEditingController commentController,
    bool listenToBloc = true,
  }) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (onResult != null) {
            onResult!(state.message);
          }
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                _showOutcomePopup(
                  context,
                  message: state.message,
                  isSuccess: true,
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (context.mounted) {
            _showOutcomePopup(
              context,
              message: state.error,
              isSuccess: false,
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        Future<void> handleTap() async {
          final token = SharedPref.getLoginData().result?.token ?? '';
          String finalComment = '..';

          if (useProvidedComment && !showHrApproveConfirmation) {
            finalComment = _resolveProvidedComment();
          } else if (showHrApproveConfirmation) {
            final decision =
                await _showHrActionSliderDialog(context, actionLabel);
            if (!context.mounted ||
                decision == null ||
                !decision.isConfirmed) {
              return;
            }
            if (useProvidedComment) {
              finalComment = _resolveProvidedComment();
            } else {
              finalComment = decision.comment.trim().isEmpty
                  ? '..'
                  : decision.comment.trim();
            }
            if (enableFakeApproveDemo) {
              await _simulateFakeActionSuccess(
                context,
                actionLabel: actionLabel,
              );
              return;
            }
          } else {
            final String? comment =
                await _showCommentDialog(context, actionLabel);
            if (!context.mounted) return;
            if (comment == null) return;
            finalComment = comment;
          }

          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.black54,
              builder: (BuildContext dialogContext) {
                return PopScope(
                  canPop: false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          if (actionLabel == 'APPROVE') {
            context.read<ApprovalBloc>().add(
                  ApproveRequest(
                    requestId: requestId,
                    type: type,
                    token: token,
                    userIds: userIds,
                    comment: finalComment,
                  ),
                );
          } else {
            context.read<ApprovalBloc>().add(
                  RejectRequest(
                    requestId: requestId,
                    type: type,
                    token: token,
                    userIds: userIds,
                    comment: finalComment,
                  ),
                );
          }
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isButtonDisabled ? null : handleTap,
            borderRadius: BorderRadius.circular(14.tr),
            child: Ink(
              height: 44.th,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.tr),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.62),
                    color.withValues(alpha: 0.16),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 18.tw,
                      height: 18.tw,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else ...[
                    Container(
                      width: 26.tw,
                      height: 26.tw,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.18),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(icon, size: 15.tsp, color: color),
                    ),
                    SizedBox(width: 7.tw),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircleActionButton(BuildContext context, String label,
      Color color, IconData icon, TextEditingController commentController,
      {bool isSelected = false, bool listenToBloc = true}) {
    return BlocConsumer<ApprovalBloc, ApprovalState>(
      // Only listen when the state actually changes to prevent duplicate calls
      listenWhen: (previous, current) {
        if (!listenToBloc) return false;
        // Only trigger listener when transitioning to a new success/failure state
        if (current is ApprovalSuccess && previous is! ApprovalSuccess) {
          return true;
        }
        if (current is ApprovalFailure && previous is! ApprovalFailure) {
          return true;
        }
        return false;
      },
      listener: (ctx, state) {
        if (state is ApprovalSuccess) {
          // Close loading overlay first
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Close loading overlay
          }

          // Call the onResult callback if provided
          if (onResult != null) {
            onResult!(state.message);
          }

          // Close main dialog - parent screen will handle refresh and count update
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);

            // Show success message after dialog closes
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                _showOutcomePopup(
                  context,
                  message: state.message,
                  isSuccess: true,
                );
              }
            });
          }
        } else if (state is ApprovalFailure) {
          // Close loading overlay first
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Close loading overlay
          }

          // For failures, show proper message popup (not snackbar).
          if (context.mounted) {
            _showOutcomePopup(
              context,
              message: state.error,
              isSuccess: false,
            );
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ApprovalLoading;
        final isButtonDisabled = disabled || isLoading;

        return AnimatedCircleButton(
          onPressed: isButtonDisabled
              ? null
              : () async {
                  final token = SharedPref.getLoginData().result?.token ?? '';
                  String finalComment = '..';
                  if (useProvidedComment) {
                    finalComment = _resolveProvidedComment();
                  } else {
                    final String? comment =
                        await _showCommentDialog(context, label);

                    // If user cancelled the dialog or context is no longer valid, don't proceed
                    if (!context.mounted) return;
                    if (comment == null) return;

                    finalComment = comment;
                  }

                  // Show loading immediately after comment is submitted
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.black54,
                      builder: (BuildContext dialogContext) {
                        return PopScope(
                          canPop: false,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  if (label == "APPROVE") {
                    context.read<ApprovalBloc>().add(
                          ApproveRequest(
                            requestId: requestId,
                            type: type,
                            token: token,
                            userIds: userIds,
                            comment: finalComment,
                          ),
                        );
                  } else if (label == "REJECT") {
                    context.read<ApprovalBloc>().add(
                          RejectRequest(
                            requestId: requestId,
                            type: type,
                            token: token,
                            userIds: userIds,
                            comment: finalComment,
                          ),
                        );
                  }
                },
          color: color,
          icon: icon,
          label: label,
          isLoading: isLoading,
          isDisabled: isButtonDisabled,
        );
      },
    );
  }

  Future<String?> _showCommentDialog(
      BuildContext context, String action) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible:
          false, // Prevent accidental dismissal by tapping outside
      builder: (ctx) {
        return AlertDialog(
          title: Text('$action Comment'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter your comment...',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), // Return null on cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isEmpty ? '..' : text);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      // Dispose controller after a frame to ensure Flutter is done with it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    });
  }
}

class _ApprovalDialogDecision {
  final bool isConfirmed;
  final String comment;

  const _ApprovalDialogDecision({
    required this.isConfirmed,
    required this.comment,
  });
}

enum ApprovalActionButtonsVariant {
  holdCircle,
  pill,
  rectangle,
  glass,
}

class AnimatedCircleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color color;
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isDisabled;

  const AnimatedCircleButton({
    super.key,
    required this.onPressed,
    required this.color,
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.isDisabled,
  });

  @override
  State<AnimatedCircleButton> createState() => _AnimatedCircleButtonState();
}

class _AnimatedCircleButtonState extends State<AnimatedCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // how long to hold
    );

    // when animation completes → trigger action
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasTriggered) {
        if (widget.onPressed != null && !widget.isDisabled) {
          _hasTriggered = true;
          widget.onPressed!();
        }
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedCircleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset trigger flag when widget becomes enabled (e.g., after loading completes)
    if (oldWidget.isDisabled && !widget.isDisabled) {
      _hasTriggered = false;
    }
    // If widget becomes disabled while animation is running, stop it
    if (!oldWidget.isDisabled && widget.isDisabled) {
      if (_controller.isAnimating) {
        _controller.reverse();
        _hasTriggered = false;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isDisabled && widget.onPressed != null && !_hasTriggered) {
      _controller.forward(from: 0); // restart animation
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse(); // released early → cancel
      _hasTriggered = false; // Reset flag if cancelled
    }
  }

  void _onTapCancel() {
    _controller.reverse();
    _hasTriggered = false; // Reset flag if cancelled
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 80.tw,
                height: 80.tw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color,
                    width: 3.tw,
                  ),
                  color:
                      widget.color.withValues(alpha: _controller.value * 0.8),
                ),
                child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 24.tw,
                            height: 24.tw,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const SizedBox.shrink()),
              );
            },
          ),
        ),
        SizedBox(height: 8.tw),
        Text(
          "HOLD TO ${widget.label}",
          style: GoogleFonts.poppins(
            fontSize: 14.tsp,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: widget.isDisabled
                ? widget.color.withValues(alpha: 0.5)
                : widget.color,
          ),
        ),
      ],
    );
  }
}

class CircleFillPainter extends CustomPainter {
  final double fillProgress;
  final Color fillColor;

  CircleFillPainter({
    required this.fillProgress,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillProgress <= 0) return;

    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final fillHeight = size.height * fillProgress;
    final startY = size.height - fillHeight;

    final rect = Rect.fromLTWH(0, startY, size.width, fillHeight);

    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    canvas.clipPath(path);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is CircleFillPainter &&
        (oldDelegate.fillProgress != fillProgress ||
            oldDelegate.fillColor != fillColor);
  }
}
