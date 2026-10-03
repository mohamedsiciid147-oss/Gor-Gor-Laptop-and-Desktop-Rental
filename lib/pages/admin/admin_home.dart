import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database.dart';
import '../login_page.dart';
import '../home_page.dart';
import 'booking_calendar.dart';
import 'bookings.dart';
import 'dashboard.dart';
import 'items.dart';
import 'users.dart';

class AdminHome extends StatefulWidget {
  static const String id = 'admin-home';
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  bool _accessChecked = false;
  bool _isAuthorized = false;
  bool _isSomali = false;
  Map<String, dynamic> _currentUser = {};
  List<Map<String, dynamic>> _pendingBookings = [];
  final Set<String> _knownRescheduleRequestIds = {};
  bool _hasLoadedBookingNotifications = false;
  Timer? _bookingNotificationTimer;

  late List<Widget> _views;

  List<String> get _titles => _isSomali
      ? ['Dashboard', 'Jadwalka', 'Qalabka', 'Booking-yada', 'Isticmaalayaasha']
      : ['Dashboard', 'Calendar', 'Items', 'Bookings', 'Users'];

  String _t(String english, String somali) => _isSomali ? somali : english;

  @override
  void initState() {
    super.initState();
    _views = [Dashboard(), BookingCalendar(), Items(), Bookings(), Users()];
    _ensureAdminAccess();
  }

  @override
  void dispose() {
    _bookingNotificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureAdminAccess() async {
    final prefs = await SharedPreferences.getInstance();
    _isSomali = prefs.getBool('useSomaliLanguage') ?? false;
    final session = prefs.getString('userData');
    if (prefs.getString('loggedIn') != 'true' || session == null) {
      if (mounted) Navigator.pushReplacementNamed(context, LoginPage.id);
      return;
    }

    try {
      final savedUser = jsonDecode(session);
      final user = await Db.get('users', id: savedUser['id']);
      if (!mounted) return;
      if (user is! Map || user['role'] != 'admin') {
        Navigator.pushReplacementNamed(context, HomePage.id);
        return;
      }
      setState(() {
        _currentUser = Map<String, dynamic>.from(user as Map);
        _isAuthorized = true;
        _accessChecked = true;
      });
      await _loadPendingBookings();
      _startBookingNotificationUpdates();
    } catch (_) {
      await prefs.remove('loggedIn');
      await prefs.remove('userData');
      if (mounted) Navigator.pushReplacementNamed(context, LoginPage.id);
    }
  }

  Future<void> _setLanguage(bool useSomali) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useSomaliLanguage', useSomali);
    if (mounted) setState(() => _isSomali = useSomali);
  }

  Widget _buildLanguageButton() => PopupMenuButton<bool>(
    tooltip: _t('Language', 'Luqad'),
    icon: const Icon(Icons.language_outlined, color: Color(0xff151843)),
    onSelected: _setLanguage,
    itemBuilder: (context) => [
      PopupMenuItem(value: false, child: Text('English${!_isSomali ? ' ✓' : ''}')),
      PopupMenuItem(value: true, child: Text('Soomaali${_isSomali ? ' ✓' : ''}')),
    ],
  );

  Future<void> _loadPendingBookings() async {
    try {
      final response = await Db.get('bookings', order: 'id.desc');
      final List<dynamic> bookings = response is List ? response : <dynamic>[];
      if (!mounted) return;
      final pendingReschedules = bookings
          .whereType<Map>()
          .map((booking) => Map<String, dynamic>.from(booking))
          .where(
            (booking) =>
                booking['rescheduleStatus']?.toString().toLowerCase() ==
                'pending',
          )
          .toList();
      final newRequest = _hasLoadedBookingNotifications
          ? pendingReschedules.cast<Map<String, dynamic>?>().firstWhere(
              (booking) => !_knownRescheduleRequestIds.contains(
                booking?['id']?.toString() ?? '',
              ),
              orElse: () => null,
            )
          : null;
      setState(() {
        _pendingBookings = bookings
            .whereType<Map>()
            .map((booking) => Map<String, dynamic>.from(booking))
            .where(
              (booking) =>
                  booking['status']?.toString().toLowerCase() == 'pending' ||
                  booking['rescheduleStatus']?.toString().toLowerCase() ==
                      'pending',
            )
            .toList();
        _knownRescheduleRequestIds
          ..clear()
          ..addAll(
            pendingReschedules.map((booking) => booking['id']?.toString() ?? ''),
          );
        _hasLoadedBookingNotifications = true;
      });
      if (newRequest != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xff155eef),
            content: Text(
              '${newRequest['user_name'] ?? 'A customer'} requested new dates for ${newRequest['productName'] ?? 'a booking'}.',
            ),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _selectedIndex = 3;
                  _views[3] = Bookings(
                    focusedBooking: newRequest,
                    onClearFocusedBooking: () {
                      setState(() => _views[3] = Bookings());
                    },
                  );
                });
              },
            ),
          ),
        );
      }
    } catch (_) {
      // The dashboard stays usable if the background notification check fails.
    }
  }

  void _startBookingNotificationUpdates() {
    _bookingNotificationTimer?.cancel();
    _bookingNotificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadPendingBookings(),
    );
  }

  void _openBookingNotifications() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingBookings.isEmpty
                      ? 'Booking notifications'
                      : '${_pendingBookings.length} booking update(s) need attention',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _pendingBookings.isEmpty
                      ? const Center(child: Text('No pending booking requests.'))
                      : ListView.separated(
                          itemCount: _pendingBookings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final booking = _pendingBookings[index];
                            final isRescheduleRequest =
                                booking['rescheduleStatus']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'pending';
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xfffef0c7),
                                  child: Icon(
                                    Icons.calendar_month_outlined,
                                    color: Color(0xffb54708),
                                  ),
                                ),
                                title: Text(
                                  isRescheduleRequest
                                      ? 'Date change: ${booking['user_name'] ?? 'Customer'} updated ${booking['productName'] ?? 'a device'}'
                                      : '${booking['user_name'] ?? 'Customer'} requested ${booking['productName'] ?? 'a device'}',
                                ),
                                subtitle: Text(
                                  isRescheduleRequest
                                      ? 'Old: ${booking['startDate'] ?? '-'} to ${booking['endDate'] ?? '-'}\nNew: ${booking['rescheduleStartDate'] ?? '-'} to ${booking['rescheduleEndDate'] ?? '-'} • New total: \$${booking['reschedulePrice'] ?? booking['price'] ?? '0'}'
                                      : '${booking['startDate'] ?? 'No start date'} to ${booking['endDate'] ?? 'No end date'}',
                                ),
                                trailing: Chip(
                                  label: Text(
                                    isRescheduleRequest
                                        ? 'New dates'
                                        : 'Pending',
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  setState(() {
                                    _selectedIndex = 3;
                                    _views[3] = Bookings(
                                      focusedBooking: booking,
                                      onClearFocusedBooking: () {
                                        setState(() => _views[3] = Bookings());
                                      },
                                    );
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingNotificationButton() {
    final pendingCount = _pendingBookings.length;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Pending booking requests',
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xff151843),
            size: 30,
          ),
          onPressed: _openBookingNotifications,
        ),
        if (pendingCount > 0)
          Positioned(
            top: 5,
            right: 3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xffd92d20),
                shape: BoxShape.circle,
              ),
              child: Text(
                pendingCount > 9 ? '9+' : pendingCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _logout(BuildContext context) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('loggedIn');
    if (mounted) {
      Navigator.pushReplacementNamed(context, LoginPage.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessChecked || !_isAuthorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint for desktop/tablet layout
        final bool isLargeScreen = constraints.maxWidth > 900;

        return Scaffold(
          backgroundColor: const Color(0xfff6f7ff),
          appBar: isLargeScreen
              ? null // No mobile AppBar on desktop
              : AppBar(
                  title: Text(_titles[_selectedIndex]),
                  actions: [_buildLanguageButton(), _buildBookingNotificationButton()],
                ),
          drawer: !isLargeScreen
              ? Drawer(child: _buildMobileDrawer(context))
              : null,
          body: Row(
            children: [
              // Beautiful, Premium Desktop Sidebar
              if (isLargeScreen) _buildDesktopSidebar(context),

              // Main Window Content Area
              Expanded(
                child: Column(
                  children: [
                    if (isLargeScreen) _buildDesktopHeader(context),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(36, 28, 36, 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xffdcdcff)),
                        ),
                        child: _views[_selectedIndex],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- BEAUTIFUL DESKTOP SIDEBAR ---
  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: 304,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff24126e), Color(0xff100650)],
        ),
      ),
      child: Column(
        children: [
          // Elegant Header Branding (No more huge colored blocks!)
          Container(
            padding: const EdgeInsets.only(
              top: 35,
              bottom: 28,
              left: 18,
              right: 18,
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset('images/logo.jpeg', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOR GOR',
                      style: TextStyle(
                      fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _t('Admin Control Center', 'Xarunta Maamulka'),
                      style: const TextStyle(
                      fontSize: 13,
                        color: Color(0xffd2d0f4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Navigation Links with custom styling
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSidebarItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: _titles[0],
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    index: 1,
                    icon: Icons.calendar_month_outlined,
                    activeIcon: Icons.calendar_month,
                    label: _titles[1],
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    index: 2,
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2,
                    label: _titles[2],
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    index: 3,
                    icon: Icons.bookmark_add_outlined,
                    activeIcon: Icons.bookmark_add,
                    label: _titles[3],
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    index: 4,
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: _titles[4],
                  ),
                ],
              ),
            ),
          ),

          // Clean, isolated Logout Button at the bottom
          Padding(
            padding: const EdgeInsets.all(18),
            child: InkWell(
              onTap: () => _logout(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.transparent,
                  border: Border.all(color: const Color(0xff8f1d64)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: const Color(0xffff5555),
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _t('Logout', 'Ka bax'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xffff5555),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for custom rounded sidebar buttons
  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? const Color(0xff4c34b7) : Colors.transparent,
          border: isSelected ? Border.all(color: const Color(0xff6753d3)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: Colors.white,
              size: 25,
            ),
            const SizedBox(width: 22),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DESKTOP TOP HEADER ---
  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 34),
      decoration: const BoxDecoration(
        color: Color(0xfff6f7ff),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Text(_t('Admin Dashboard', 'Dashboard-ka Admin'), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold, color: Color(0xff151843))),
                const SizedBox(width: 12),
                const Icon(Icons.circle, size: 12, color: Color(0xff6547e8)),
              ]),
              const SizedBox(height: 5),
              Text(
                _isSomali
                    ? 'Maamul ${_titles[_selectedIndex].toLowerCase()}'
                    : 'Manage your ${_titles[_selectedIndex].toLowerCase()}',
                style: const TextStyle(fontSize: 17, color: Color(0xff6b7194)),
              ),
            ],
          ),
          Row(
            children: [
              _buildLanguageButton(),
              const SizedBox(width: 14),
              _buildBookingNotificationButton(),
              const SizedBox(width: 26),
              PopupMenuButton<String>(
                tooltip: 'Account menu',
                offset: const Offset(0, 56),
                onSelected: (value) {
                  if (value == 'logout') {
                    _logout(context);
                  } else if (value == 'profile') {
                    final adminName = _currentUser['name']?.toString() ?? 'Admin Name';
                    final adminEmail = _currentUser['email']?.toString() ?? 'admin@gorgor.com';
                    final adminPhone =
                        _currentUser['mobile']?.toString() ??
                        _currentUser['phone']?.toString() ??
                        '+252 615 XXXXX';
                    final adminRole = _currentUser['role']?.toString() ?? 'System Administrator';
                    final accountStatus = _currentUser['status']?.toString() ?? 'Active';

                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (dialogContext) {
                        return Dialog(
                          insetPadding: const EdgeInsets.all(20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Container(
                            width: 920,
                            padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                            decoration: BoxDecoration(
                              color: const Color(0xfff5f5f5),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Admin Profile Settings',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff1a1a1a),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: const BoxDecoration(
                                              color: Color(0xffd9d9d9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 28,
                                                color: Color(0xff5f5f5f),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Change Photo',
                                            style: TextStyle(
                                              color: Color(0xff2d2d2d),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 26),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Role & Status',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xff2a2a2a),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildInfoBox('Role / Position', adminRole),
                                            const SizedBox(height: 12),
                                            _buildInfoBox('Account Status', accountStatus),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Personal Information',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xff2a2a2a),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildFieldLabel('Full Name'),
                                      _buildInputField(adminName),
                                      const SizedBox(height: 12),
                                      _buildFieldLabel('Email Address'),
                                      _buildInputField(adminEmail),
                                      const SizedBox(height: 12),
                                      _buildFieldLabel('Phone Number'),
                                      _buildInputField(adminPhone),
                                    ],
                                  ),
                                  const SizedBox(height: 26),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Color(0xff3f3f3f),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xff3d2bcb),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 26,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 10),
                        Text('Admin profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: const CircleAvatar(
                  backgroundColor: Color(0xff3e25cb),
                  radius: 27,
                  child: Text(
                    'G',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffececf4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xff6e6e7a),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff1a1a1a),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xff333333),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInputField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffececf4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xff1a1a1a),
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildPasswordField(String hintText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffececf4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: Color(0xff4a4a4a)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hintText,
              style: const TextStyle(
                color: Color(0xff6f6f75),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MOBILE DRAWER ---
  Widget _buildMobileDrawer(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: Colors.deepPurple),
          child: Text(
            _t('Gorgor Admin', 'Maamulka Gorgor'),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard_outlined),
          title: Text(_titles[0]),
          selected: _selectedIndex == 0,
          onTap: () {
            setState(() => _selectedIndex = 0);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(_titles[1]),
          selected: _selectedIndex == 1,
          onTap: () {
            setState(() => _selectedIndex = 1);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: Text(_titles[2]),
          selected: _selectedIndex == 2,
          onTap: () {
            setState(() => _selectedIndex = 2);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.bookmark_add),
          title: Text(_titles[3]),
          selected: _selectedIndex == 3,
          onTap: () {
            setState(() => _selectedIndex = 3);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.people),
          title: Text(_titles[4]),
          selected: _selectedIndex == 4,
          onTap: () {
            setState(() => _selectedIndex = 4);
            Navigator.pop(context);
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text(_t('Language', 'Luqad')),
          trailing: Text(_isSomali ? 'Soomaali' : 'English'),
          onTap: () {
            Navigator.pop(context);
            _setLanguage(!_isSomali);
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(_t('Logout', 'Ka bax'), style: const TextStyle(color: Colors.red)),
          onTap: () => _logout(context),
        ),
      ],
    );
  }
}

