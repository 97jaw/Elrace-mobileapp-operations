import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';

import '../../../../../utils/di.dart';
import 'bloc/contact_bloc.dart';
import 'widgets/call_list_header.dart';
import 'widgets/employee_contact_tile.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _contactBloc = sl.get<ContactBloc>();
  int? expandedIndex;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contactBloc.add(GetEmployeeLisET());
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          HomeNavigation.handleSystemBack(context);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverPersistentHeader(
                pinned: true,
                delegate: CallListHeaderDelegate(
                  topBarExtent: SubAppGlassAppBar.extent(context),
                  searchController: _searchController,
                  onSearchChanged: (value) {
                    _contactBloc.add(SearchContactsEvent(value));
                  },
                  onSearchClear: () {
                    _searchController.clear();
                    _contactBloc.add(const SearchContactsEvent(''));
                  },
                ),
              ),
            ];
          },
          body: BlocBuilder<ContactBloc, ContactState>(
            bloc: _contactBloc,
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      padding: const EdgeInsets.only(top: 9, bottom: 8),
                      alignment: Alignment.center,
                      child: Container(
                        width: 70,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E5E5),
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                        ),
                      ),
                    ),
                  ),
                  if (state is ContactLoadingState && state.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: GlassContactsListPlaceholder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                      ),
                    )
                  else if (state is EmployeeListLoaded)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final emp = state.employees[index];
                          final isExpanded = expandedIndex == index;
                          final isLast = index == state.employees.length - 1;

                          return EmployeeContactTile(
                            imageUrl: emp.profilePhotoUrl.toString(),
                            displayName:
                                formatEmployeeDisplayName(emp.name ?? ''),
                            department: emp.department ?? '',
                            job: emp.jobId.toString(),
                            empId: emp.empId ?? emp.id.toString(),
                            isExpanded: isExpanded,
                            showDivider: !isLast,
                            canCall: emp.hasCompanyPhone,
                            onTap: () {
                              setState(() {
                                expandedIndex = isExpanded ? null : index;
                              });
                            },
                            onCall: () {
                              final phone = emp.companyPhone;
                              if (phone == null) return;
                              _makePhoneCall('tel:$phone');
                            },
                            onWhatsApp: () =>
                                _openWhatsApp(emp.mobilePhone.toString()),
                            onEmail: () => _sendEmail(emp.name!),
                          );
                        },
                        childCount: state.employees.length,
                      ),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Unable to load contacts',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) {
                        final systemBottomInset = context.systemBottomInset;
                        final totalPadding = systemBottomInset > 0
                            ? systemBottomInset + 20.h
                            : 150.h;
                        return SizedBox(height: totalPadding);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final url = 'https://wa.me/$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  Future<void> _sendEmail(String name) async {
    final url = 'mailto:?subject=Hello $name';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch email';
    }
  }
}
