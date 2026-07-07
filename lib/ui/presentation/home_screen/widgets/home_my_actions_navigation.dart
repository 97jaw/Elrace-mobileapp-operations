import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_actions/screens/hr_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/invoice_my_actions_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/my_requests_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/petty_cash_my_action_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/rfq_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signatures_screen.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:flutter/material.dart';

enum HomeMyAction {
  hr,
  rfq,
  timesheets,
  invoice,
  pettyCash,
  signature,
  siteManagement,
  myRequests,
}

/// Central navigation for home quick actions and expanded my-actions row.
abstract final class HomeMyActionsNavigation {
  static NavigatorState _nav(BuildContext context) =>
      Navigator.of(context, rootNavigator: true);

  static void open(BuildContext context, HomeMyAction action) {
    if (!SharedPref.isUserAuthenticated()) {
      Util.pushPage(const SignInScreen(), context);
      return;
    }

    switch (action) {
      case HomeMyAction.hr:
        _nav(context).push(
          SlideRightPageRoute(
            child: const HrScreen(),
            settings: const RouteSettings(name: '/hr'),
          ),
        );
      case HomeMyAction.rfq:
        _nav(context).push(
          SlideRightPageRoute(
            child: const RfqScreen(),
            settings: const RouteSettings(name: '/rfq'),
          ),
        );
      case HomeMyAction.timesheets:
        _nav(context).pushNamed(TimesheetRouteNames.home);
      case HomeMyAction.siteManagement:
        _nav(context).pushNamed(TimesheetRouteNames.siteManagementHome);
      case HomeMyAction.invoice:
        _nav(context).push(
          SlideRightPageRoute(
            child: const InvoiceMyActionsScreen(),
            settings: const RouteSettings(name: '/invoice_my_actions'),
          ),
        );
      case HomeMyAction.pettyCash:
        _nav(context).push(
          SlideRightPageRoute(
            child: const PettyCashMyActionScreen(),
            settings: const RouteSettings(name: '/petty_cash_my_actions'),
          ),
        );
      case HomeMyAction.signature:
        _nav(context).push(
          SlideRightPageRoute(
            child: const SignaturesScreen(),
            settings: const RouteSettings(name: '/signatures'),
          ),
        );
      case HomeMyAction.myRequests:
        _nav(context).push(
          SlideRightPageRoute(
            child: const MyRequestsScreen(),
            settings: const RouteSettings(name: '/my_requests'),
          ),
        );
    }
  }
}
