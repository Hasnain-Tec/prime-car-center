import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import 'admin/audit_screen.dart';
import 'admin/roles_screen.dart';
import 'admin/settings_screen.dart';
import 'admin/users_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'financial_screen.dart';
import 'job_records_screen.dart';
import 'new_job_screen.dart';

class _NavPage {
  final String label;
  final String mobileLabel;
  final IconData icon;
  final Widget Function() builder;

  const _NavPage(
    this.label,
    this.icon,
    this.builder, {
    String? mobileLabel,
  }) : mobileLabel = mobileLabel ?? label;
}

class HomeShell extends StatefulWidget {
  final SessionController session;

  const HomeShell({
    super.key,
    required this.session,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  List<_NavPage> get pages {
    final session = widget.session;

    return [
      _NavPage(
        'Dashboard',
        Icons.dashboard_outlined,
        () => DashboardScreen(session: session),
      ),
      if (session.can('jobs.create'))
        _NavPage(
          'New Entry',
          Icons.add_a_photo_outlined,
          () => NewJobScreen(session: session),
        ),
      if (session.can('jobs.view_all') ||
          session.can('jobs.view_assigned') ||
          session.can('jobs.view_created'))
        _NavPage(
          'Job Records',
          Icons.receipt_long_outlined,
          () => JobRecordsScreen(session: session),
          mobileLabel: 'Records',
        ),
      if (session.can('expenses.create') ||
          session.can('expenses.view_own') ||
          session.can('expenses.view_all'))
        _NavPage(
          'Expenses',
          Icons.payments_outlined,
          () => ExpensesScreen(session: session),
        ),
      if (session.can('finance.view_profit_loss'))
        _NavPage(
          'Summary',
          Icons.analytics_outlined,
          () => FinancialScreen(session: session),
        ),
      if (session.can('users.view'))
        _NavPage(
          'Users',
          Icons.people_alt_outlined,
          () => UsersScreen(session: session),
        ),
      if (session.can('roles.manage') || session.can('users.view'))
        _NavPage(
          'Roles',
          Icons.admin_panel_settings_outlined,
          () => RolesScreen(session: session),
        ),
      if (session.can('settings.manage'))
        _NavPage(
          'Workshop Info',
          Icons.settings_outlined,
          () => SettingsScreen(session: session),
        ),
      if (session.can('audit.view'))
        _NavPage(
          'Activity Logs',
          Icons.history_outlined,
          () => AuditScreen(session: session),
        ),
    ];
  }

  Future<void> _handleAccountAction(String action) async {
    if (action != 'logout') {
      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.logout,
                color: PccColors.hazard,
              ),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: PccColors.hazard,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      await widget.session.logout();
    }
  }

  Widget _buildWorkshopLogo() {
    final logoUrl = widget.session.workshop.logoUrl?.trim();

    Widget fallbackLogo() {
      return const Padding(
        padding: EdgeInsets.all(5),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'PCC',
            style: TextStyle(
              color: PccColors.charcoal,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: logoUrl != null && logoUrl.isNotEmpty
            ? Colors.white
            : PccColors.hazard,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: logoUrl == null || logoUrl.isEmpty
          ? fallbackLogo()
          : Image.network(
              logoUrl,
              key: ValueKey(logoUrl),
              width: 46,
              height: 46,
              fit: BoxFit.contain,
              gaplessPlayback: false,
              errorBuilder: (context, error, stackTrace) {
                return fallbackLogo();
              },
            ),
    );
  }

  Widget _buildAccountMenu() {
    final user = widget.session.user!;
    final roleName = user.roleName?.trim();

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: _handleAccountAction,
      icon: const Icon(
        Icons.account_circle_outlined,
        size: 30,
      ),
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            enabled: false,
            child: SizedBox(
              width: 240,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: PccColors.hazard.withValues(alpha: 0.14),
                    child: Text(
                      user.fullName.trim().isNotEmpty
                          ? user.fullName.trim()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: PccColors.hazardDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PccColors.charcoal,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF68727D),
                            fontSize: 12,
                          ),
                        ),
                        if (roleName != null && roleName.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PccColors.hazard.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              roleName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PccColors.hazardDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.redAccent,
                  size: 21,
                ),
                SizedBox(width: 12),
                Text(
                  'Sign out',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationPages = pages;

    if (index >= navigationPages.length) {
      index = 0;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final desktop = screenWidth >= 860;
    final expandedDesktopNavigation = screenWidth >= 1180;

    final mobilePages = navigationPages.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 12,
        title: Row(
          children: [
            _buildWorkshopLogo(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.workshop.name.toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (screenWidth >= 380)
                    const Text(
                      'Workshop Job Records & Invoicing',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFB9C2CC),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _buildAccountMenu(),
          const SizedBox(width: 5),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: ColoredBox(
              color: PccColors.hazard,
            ),
          ),
        ),
      ),
      body: desktop
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: PccColors.charcoal2,
                  scrollable: true,
                  selectedIndex: index,
                  onDestinationSelected: (value) {
                    setState(() {
                      index = value;
                    });
                  },
                  extended: expandedDesktopNavigation,
                  labelType: expandedDesktopNavigation
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(
                    color: PccColors.hazard,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: Color(0xFFC3CAD2),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Color(0xFFC3CAD2),
                  ),
                  destinations: navigationPages.map((page) {
                    return NavigationRailDestination(
                      icon: Icon(page.icon),
                      label: Text(page.label),
                    );
                  }).toList(),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${navigationPages[index].label}-'
                      '${widget.session.user!.id}',
                    ),
                    child: navigationPages[index].builder(),
                  ),
                ),
              ],
            )
          : KeyedSubtree(
              key: ValueKey(
                '${navigationPages[index].label}-'
                '${widget.session.user!.id}',
              ),
              child: navigationPages[index].builder(),
            ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 72,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                  (states) {
                    final selected = states.contains(WidgetState.selected);

                    return TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? PccColors.charcoal
                          : const Color(0xFF625B58),
                    );
                  },
                ),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  selectedIndex: index < mobilePages.length ? index : 0,
                  onDestinationSelected: (value) {
                    setState(() {
                      index = value;
                    });
                  },
                  destinations: mobilePages.map((page) {
                    return NavigationDestination(
                      icon: Icon(
                        page.icon,
                        size: 22,
                      ),
                      selectedIcon: Icon(
                        page.icon,
                        size: 24,
                        color: PccColors.hazardDark,
                      ),
                      label: page.mobileLabel,
                    );
                  }).toList(),
                ),
              ),
            ),
      drawer: !desktop && navigationPages.length > 5
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        24,
                        18,
                        18,
                      ),
                      color: PccColors.charcoal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWorkshopLogo(),
                          const SizedBox(height: 16),
                          Text(
                            widget.session.user!.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.session.user!.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB9C2CC),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Administration',
                            style: TextStyle(
                              color: PccColors.hazard,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                        children: [
                          for (var i = 5; i < navigationPages.length; i++)
                            ListTile(
                              leading: Icon(
                                navigationPages[i].icon,
                              ),
                              title: Text(
                                navigationPages[i].label,
                              ),
                              selected: index == i,
                              selectedColor: PccColors.hazardDark,
                              selectedTileColor: PccColors.hazard.withValues(
                                alpha: 0.08,
                              ),
                              onTap: () {
                                Navigator.pop(context);

                                setState(() {
                                  index = i;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
