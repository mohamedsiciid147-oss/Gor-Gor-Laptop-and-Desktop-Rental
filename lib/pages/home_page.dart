import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import 'login_page.dart';
import 'admin/admin_home.dart';

class HomePage extends StatefulWidget {
  static const String id = 'home-page';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  Map<String, dynamic>? currentUser;

  List<dynamic> items = [];
  List<dynamic> myBookings = [];
  List<dynamic> _allBookings = [];
  Set<String> _dismissedNotificationIds = {};
  RangeValues? _priceRange;
  final TextEditingController _deviceSearchController = TextEditingController();
  final GlobalKey _discoverDevicesKey = GlobalKey();
  String _deviceSearchQuery = '';
  String _selectedCategory = 'All';
  String _selectedRam = 'All';
  String _historyFilter = 'All';
  bool _isSomali = false;
  bool isLoading = false;
  Timer? _liveUpdateTimer;

  @override
  void initState() {
    super.initState();
    _ensureUserAccess();
  }

  Future<void> _ensureUserAccess() async {
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
      if (user is! Map || user['role'] == 'admin') {
        Navigator.pushReplacementNamed(context, AdminHome.id);
        return;
      }
      final refreshedPrefs = await SharedPreferences.getInstance();
      await refreshedPrefs.setString('userData', jsonEncode(user));
      await _loadUserAndData();
      _startLiveUpdates();
    } catch (_) {
      await prefs.remove('loggedIn');
      await prefs.remove('userData');
      if (mounted) Navigator.pushReplacementNamed(context, LoginPage.id);
    }
  }

  Future<void> _loadUserAndData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('userData');
      if (userDataStr != null) {
        currentUser = jsonDecode(userDataStr);
      }

      final dismissed = prefs.getStringList(
        'dismissedBookingNotifications_${currentUser?['id']}',
      );
      _dismissedNotificationIds = (dismissed ?? []).toSet();

      await Future.wait([_fetchItems(), _fetchBookings()]);
    } catch (e) {
      debugPrint('Initialization Error: $e');
      _showSnackBar('Initialization Error: $e', Colors.redAccent);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchItems() async {
    try {
      List<dynamic> fetchedItems = await Db.get('items');
      if (!mounted) return;
      setState(() => items = fetchedItems);
    } catch (e) {
      debugPrint('Error getting items: $e');
    }
  }

  Future<void> _fetchBookings() async {
    try {
      List<dynamic> bookings = await Db.get('bookings');
      if (!mounted) return;
      setState(() {
        _allBookings = bookings;
        myBookings = bookings
            .where(
              (b) => b['userId']?.toString() == currentUser?['id']?.toString(),
            )
            .toList();
      });
    } catch (e) {
      debugPrint('Error getting bookings: $e');
    }
  }

  void _startLiveUpdates() {
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || isLoading) return;
      await Future.wait([_fetchItems(), _fetchBookings()]);
    });
  }

  String _t(String english, String somali) => _isSomali ? somali : english;

  Future<void> _setLanguage(bool useSomali) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useSomaliLanguage', useSomali);
    if (mounted) setState(() => _isSomali = useSomali);
  }

  void _browseRentals() {
    final discoverSection = _discoverDevicesKey.currentContext;
    if (discoverSection == null) return;

    Scrollable.ensureVisible(
      discoverSection,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0,
    );
  }

  @override
  void dispose() {
    _liveUpdateTimer?.cancel();
    _deviceSearchController.dispose();
    super.dispose();
  }

  bool _blocksAvailability(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    return status == 'pending' || status == 'confirmed';
  }

  bool _rangesOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return !endA.isBefore(startB) && !startA.isAfter(endB);
  }

  bool _isDateUnavailable(Map<String, dynamic> item, DateTime date) {
    final itemId = item['id']?.toString();
    final day = DateTime(date.year, date.month, date.day);
    return _allBookings.whereType<Map>().any((booking) {
      if (booking['itemId']?.toString() != itemId ||
          !_blocksAvailability(Map<String, dynamic>.from(booking))) {
        return false;
      }
      try {
        final start = DateTime.parse(booking['startDate'].toString());
        final end = DateTime.parse(booking['endDate'].toString());
        return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(DateTime(end.year, end.month, end.day));
      } catch (_) {
        return false;
      }
    });
  }

  bool _hasBookingConflict(
    Map<String, dynamic> item,
    DateTime start,
    DateTime end,
  ) {
    final itemId = item['id']?.toString();
    return _allBookings.whereType<Map>().any((booking) {
      if (booking['itemId']?.toString() != itemId ||
          !_blocksAvailability(Map<String, dynamic>.from(booking))) {
        return false;
      }
      try {
        final bookedStart = DateTime.parse(booking['startDate'].toString());
        final bookedEnd = DateTime.parse(booking['endDate'].toString());
        return _rangesOverlap(start, end, bookedStart, bookedEnd);
      } catch (_) {
        return false;
      }
    });
  }

  /// Shows whether the device is in use today. Future dates can still be booked.
  bool _isItemRented(dynamic item) {
    final today = DateTime.now();
    return _isDateUnavailable(item, today);
  }

  bool _isItemReserved(Map<String, dynamic> item) {
    final itemId = item['id']?.toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _allBookings.whereType<Map>().any((booking) {
      if (booking['itemId']?.toString() != itemId ||
          !_blocksAvailability(Map<String, dynamic>.from(booking))) {
        return false;
      }
      final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
      return start != null &&
          DateTime(start.year, start.month, start.day).isAfter(today);
    });
  }

  bool _isOperationallyAvailable(Map<String, dynamic> item) =>
      (item['operationalStatus']?.toString().toLowerCase() ?? 'available') ==
      'available';

  Future<void> _createBooking(
    Map<String, dynamic> item,
    DateTime start,
    DateTime end,
    double totalCost,
  ) async {
    if (currentUser == null) {
      _showSnackBar('Session expired. Please log in again.', Colors.redAccent);
      return;
    }
    if (!_isOperationallyAvailable(item)) {
      _showSnackBar(
        'This device is currently unavailable for rental.',
        Colors.redAccent,
      );
      return;
    }

    final days = end.difference(start).inDays + 1;

    setState(() => isLoading = true);
    try {
      // Refresh immediately before saving so two users cannot reserve the same
      // dates merely because one of them has an old screen open.
      final latestBookings = await Db.get('bookings');
      _allBookings = latestBookings;
      if (_hasBookingConflict(item, start, end)) {
        _showSnackBar(
          'Those dates have just been booked. Please choose another range.',
          Colors.redAccent,
        );
        return;
      }
      String formattedEndDate = end.toIso8601String().substring(0, 10);

      // 1. Post a record to the historical bookings log
      Map<String, dynamic> bookingPayload = {
        'userId': currentUser!['id'],
        'user_name': currentUser!['name'] ?? 'Anonymous User',
        'itemId': item['id'],
        'productName': item['name'],
        'productImage': item['image'],
        'startDate': start.toIso8601String().substring(0, 10),
        'endDate': formattedEndDate,
        // Keep this payload aligned with the current Supabase schema.
        // The rental length is derived from startDate/endDate when needed.
        'price': totalCost,
        'status': 'Pending',
      };
      await Db.post('bookings', bookingPayload);

      _showSnackBar(
        'Booking created. Your selected rental dates are now reserved.',
        Colors.green.shade600,
      );

      // Refresh local states completely
      await _loadUserAndData();
      setState(() => _currentIndex = 1);
    } catch (e) {
      _showSnackBar('Booking process failed: $e', Colors.redAccent);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    if (start != null && start.isBefore(normalizedToday)) {
      _showSnackBar(
        'A rental that has already started cannot be cancelled here.',
        Colors.redAccent,
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text(
          'The selected dates will become available to other customers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      await Db.update('bookings', booking['id'], {'status': 'Cancelled'});
      await _loadUserAndData();
      _showSnackBar(
        'Reservation cancelled. The dates are available again.',
        Colors.green.shade600,
      );
    } catch (e) {
      _showSnackBar('Could not cancel reservation: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _requestReschedule(Map<String, dynamic> booking) async {
    DateTime? start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    DateTime? end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
    final reasonController = TextEditingController();
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final originalStart = start;
    final originalEnd = end;
    final originalDays = originalStart != null && originalEnd != null
        ? originalEnd.difference(originalStart).inDays + 1
        : 1;
    final originalPrice =
        double.tryParse(booking['price']?.toString() ?? '0') ?? 0;
    final dailyPrice = originalDays > 0 ? originalPrice / originalDays : 0;

    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final newDays = start != null && end != null
              ? end!.difference(start!).inDays + 1
              : 0;
          final newPrice = newDays > 0 ? dailyPrice * newDays : 0.0;
          final priceDifference = newPrice - originalPrice;
          return AlertDialog(
            title: const Text('Request new rental dates'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('New start date'),
                    subtitle: Text(start == null ? 'Choose a date' : start!.toIso8601String().substring(0, 10)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final initialDate = start != null && !start!.isBefore(firstDate) ? start! : firstDate;
                      final selected = await showDatePicker(
                        context: dialogContext,
                        firstDate: firstDate,
                        lastDate: firstDate.add(const Duration(days: 365)),
                        initialDate: initialDate,
                      );
                      if (selected != null) setDialogState(() => start = selected);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('New end date'),
                    subtitle: Text(end == null ? 'Choose a date' : end!.toIso8601String().substring(0, 10)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final minimumDate = start != null && start!.isAfter(firstDate) ? start! : firstDate;
                      final initialDate = end != null && !end!.isBefore(minimumDate) ? end! : minimumDate;
                      final selected = await showDatePicker(
                        context: dialogContext,
                        firstDate: minimumDate,
                        lastDate: firstDate.add(const Duration(days: 365)),
                        initialDate: initialDate,
                      );
                      if (selected != null) setDialogState(() => end = selected);
                    },
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffeef5ff),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New total: \$${newPrice.toStringAsFixed(2)} for $newDays day(s)', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          priceDifference == 0
                              ? 'No price change'
                              : priceDifference > 0
                              ? '+\$${priceDifference.toStringAsFixed(2)} for the extra days'
                              : '-\$${priceDifference.abs().toStringAsFixed(2)} for fewer days',
                          style: TextStyle(color: priceDifference > 0 ? const Color(0xffb54708) : const Color(0xff16955a)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: start != null && end != null && !end!.isBefore(start!)
                    ? () => Navigator.pop(dialogContext, {
                        'start': start!,
                        'end': end!,
                        'reason': reasonController.text.trim(),
                        'price': newPrice,
                      })
                    : null,
                child: const Text('Send request'),
              ),
            ],
          );
        },
      ),
    );
    reasonController.dispose();
    if (request == null) return;

    setState(() => isLoading = true);
    try {
      final newStart = request['start'] as DateTime;
      final newEnd = request['end'] as DateTime;
      await Db.update('bookings', booking['id'], {
        'rescheduleStartDate': newStart.toIso8601String().substring(0, 10),
        'rescheduleEndDate': newEnd.toIso8601String().substring(0, 10),
        'rescheduleReason': request['reason'],
        'rescheduleStatus': 'Pending',
        'reschedulePrice': request['price'],
      });
      await _loadUserAndData();
      _showSnackBar('Your date-change request was sent to the admin.', Colors.green.shade600);
    } catch (e) {
      _showSnackBar('Could not send your request: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _notifications {
    return myBookings
        .whereType<Map>()
        .map((booking) => Map<String, dynamic>.from(booking))
        .where(
          (booking) =>
              !_dismissedNotificationIds.contains(_notificationId(booking)),
        )
        .where(
          (booking) => [
            'pending',
            'confirmed',
            'cancelled',
            'returned',
          ].contains(booking['status']?.toString().toLowerCase()),
        )
        .toList();
  }

  bool _isDueSoon(Map<String, dynamic> booking) {
    if (booking['status']?.toString().toLowerCase() != 'confirmed') {
      return false;
    }
    final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
    if (end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(end.year, end.month, end.day);
    final daysUntilDue = dueDate.difference(today).inDays;
    return daysUntilDue == 0 || daysUntilDue == 1;
  }

  String _notificationId(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString() ?? '';
    if (_isDueSoon(booking)) return 'due-$bookingId';
    return 'status-$bookingId-${booking['status']?.toString().toLowerCase()}';
  }

  String _notificationTitle(Map<String, dynamic> booking) {
    final itemName = booking['productName']?.toString() ?? 'Your rental';
    if (_isDueSoon(booking)) {
      final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = end == null
          ? today
          : DateTime(end.year, end.month, end.day);
      final daysUntilDue = dueDate.difference(today).inDays;
      return daysUntilDue == 0
          ? 'Due-date reminder: return $itemName today'
          : 'Due-date reminder: return $itemName tomorrow';
    }
    switch (booking['status']?.toString().toLowerCase()) {
      case 'pending':
        return 'Booking confirmation: $itemName request received';
      case 'confirmed':
        return 'Booking confirmed: $itemName is ready';
      case 'cancelled':
        return 'Booking cancelled: $itemName';
      case 'returned':
        return 'Rental returned: $itemName';
      default:
        return '$itemName booking updated';
    }
  }

  String _extractDetailValue(String? raw, List<String> keys) {
    if (raw == null || raw.isEmpty) return '';
    for (final key in keys) {
      final pattern = RegExp(
        '${RegExp.escape(key)}\\s*[:\\-]?\\s*(.+?)(?:\\||\$)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  String _detailValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    final details = source['details']?.toString() ?? '';
    return _extractDetailValue(details, keys);
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    final item = items.firstWhere(
      (entry) => entry['id']?.toString() == booking['itemId']?.toString(),
      orElse: () => <String, dynamic>{},
    );
    final itemMap = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final details = (itemMap['details'] ?? booking['details'] ?? '').toString();
    final productName = booking['productName']?.toString() ?? itemMap['name']?.toString() ?? 'Equipment rental';
    final imageUrl = booking['productImage']?.toString() ?? itemMap['image']?.toString() ?? '';
    final rentalStart = booking['startDate']?.toString() ?? '-';
    final rentalEnd = booking['endDate']?.toString() ?? '-';
    final totalCost = booking['price']?.toString() ?? '0';
    final parsedStart = DateTime.tryParse(rentalStart);
    final parsedEnd = DateTime.tryParse(rentalEnd);
    final computedDays = parsedStart != null && parsedEnd != null
        ? (parsedEnd.difference(parsedStart).inDays + 1)
        : 0;
    final days = booking['days'] != null && booking['days'].toString().trim().isNotEmpty
        ? booking['days'].toString()
        : computedDays.toString();
    final returnCondition = booking['returnCondition']?.toString() ?? 'Inspected & approved';
    final processor = _detailValue(itemMap, ['processor', 'cpu'])
        .isNotEmpty
        ? _detailValue(itemMap, ['processor', 'cpu'])
        : _extractDetailValue(details, ['processor', 'cpu']);
    final ram = _detailValue(itemMap, ['ram', 'memory']).isNotEmpty
        ? _detailValue(itemMap, ['ram', 'memory'])
        : _extractDetailValue(details, ['ram', 'memory']);
    final storage = _detailValue(itemMap, ['storage', 'ssd', 'disk']).isNotEmpty
        ? _detailValue(itemMap, ['storage', 'ssd', 'disk'])
        : _extractDetailValue(details, ['storage', 'ssd', 'disk']);
    final gpu = _detailValue(itemMap, ['gpu', 'graphics', 'vga']).isNotEmpty
        ? _detailValue(itemMap, ['gpu', 'graphics', 'vga'])
        : _extractDetailValue(details, ['gpu', 'graphics', 'vga']);
    final serial = _detailValue(itemMap, ['serialNumber', 'serial', 'serial number']).isNotEmpty
        ? _detailValue(itemMap, ['serialNumber', 'serial', 'serial number'])
        : _extractDetailValue(details, ['serialNumber', 'serial', 'serial number']);
    final specEntries = <MapEntry<String, String>>[
      if (processor.isNotEmpty) MapEntry('CPU', processor),
      if (ram.isNotEmpty) MapEntry('RAM', ram),
      if (storage.isNotEmpty) MapEntry('Storage', storage),
      if (gpu.isNotEmpty) MapEntry('GPU', gpu),
      if (serial.isNotEmpty) MapEntry('Serial Number', serial),
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Faahfaahinta Kireysiga (Rental Details) - $productName',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff0b1b45),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 800;
                    return Flex(
                      direction: compact ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff4f6fb),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          height: 180,
                                          fit: BoxFit.contain,
                                        )
                                      : const Icon(
                                          Icons.laptop_mac_outlined,
                                          size: 120,
                                          color: Color(0xff7d8aa5),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Sifooyinka Qalabka',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff0b1b45),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (specEntries.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'No specifications available',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                ...specEntries.map(
                                  (entry) => _buildSpecRow(entry.key, entry.value),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18, height: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Faahfaahinta Lacag Bixinta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff0b1b45),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Rental Dates', '$rentalStart to $rentalEnd'),
                              _buildInfoRow('Total Days', days),
                              _buildInfoRow('Total Cost', '\$$totalCost'),
                              _buildInfoRow('Return Condition', returnCondition),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xff0b1b45),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xff0b1b45),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(value, style: const TextStyle(color: Color(0xff374a60))),
          ),
        ],
      ),
    );
  }

  Future<void> _dismissNotifications() async {
    final ids = _notifications.map(_notificationId).toSet();
    final updated = {..._dismissedNotificationIds, ...ids};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'dismissedBookingNotifications_${currentUser?['id']}',
      updated.toList(),
    );
    if (mounted) setState(() => _dismissedNotificationIds = updated);
  }

  void _openNotifications() {
    final notifications = _notifications;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Booking updates',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _dismissNotifications();
                          Navigator.pop(context);
                        },
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(child: Text('You are all caught up.'))
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final booking = notifications[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(
                                  booking['status'],
                                ).withOpacity(.13),
                                child: Icon(
                                  Icons.notifications_active_outlined,
                                  color: _getStatusColor(booking['status']),
                                ),
                              ),
                              title: Text(_notificationTitle(booking)),
                              subtitle: Text(
                                '${booking['startDate']} to ${booking['endDate']}',
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

  void _openProfile() {
    final name = TextEditingController(
      text: currentUser?['name']?.toString() ?? '',
    );
    final mobile = TextEditingController(
      text: currentUser?['mobile']?.toString() ?? '',
    );
    final email = currentUser?['email']?.toString() ?? '';
    var returnLocation = 'Xarunta Gor Gor';
    var avatar = currentUser?['avatar']?.toString() ??
        currentUser?['photo']?.toString() ??
        currentUser?['image']?.toString() ??
        '';

    InputDecoration fieldDecoration(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: const Color(0xfffafbff),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xffaeb4c0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xffaeb4c0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xff155eef), width: 2),
        ),
      );
    }

    Future<void> pickProfilePhoto(StateSetter setDialogState) async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.single.bytes == null) return;

        final file = result.files.single;
        final extension = file.extension?.toLowerCase() ?? 'png';
        final fileName =
            'profile_${currentUser?['id'] ?? DateTime.now().millisecondsSinceEpoch}.$extension';
        final storedFileName = await Db.uploadImage(
          bucket: 'images',
          fileName: fileName,
          fileBytes: file.bytes,
        );
        final avatarUrl = Db.getImageUrl(
          bucket: 'images',
          fileName: storedFileName,
        );
        final updated = await Db.update(
          'users',
          currentUser!['id'],
          {'avatar': avatarUrl},
        );
        final nextUser = updated is List && updated.isNotEmpty
            ? Map<String, dynamic>.from(updated.first as Map)
            : {...currentUser!, 'avatar': avatarUrl};
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(nextUser));
        if (mounted) setState(() => currentUser = nextUser);
        setDialogState(() => avatar = avatarUrl);
        _showSnackBar('Profile photo updated.', Colors.green.shade600);
      } catch (e) {
        _showSnackBar('Could not update profile photo: $e', Colors.redAccent);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'My profile',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff101f46),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, size: 27),
                        tooltip: 'Close profile',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 570;
                      final fields = Column(
                        children: [
                          TextField(
                            controller: name,
                            decoration: fieldDecoration('Full name'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: mobile,
                            keyboardType: TextInputType.phone,
                            decoration: fieldDecoration('Mobile number'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: TextEditingController(text: email),
                            readOnly: true,
                            decoration: fieldDecoration('Email Address'),
                          ),
                        ],
                      );
                      final profileImage = avatar.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                avatar,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 64,
                                  color: Color(0xff155eef),
                                ),
                              ),
                            )
                          : const CircleAvatar(
                              radius: 56,
                              backgroundColor: Color(0xffe4edff),
                              child: Icon(
                                Icons.person,
                                size: 64,
                                color: Color(0xff155eef),
                              ),
                            );
                      final avatarSection = Column(
                        children: [
                          Container(
                            width: 122,
                            height: 122,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xff155eef),
                                width: 2,
                              ),
                            ),
                            child: profileImage,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => pickProfilePhoto(setDialogState),
                            child: const Text('Update Photo'),
                          ),
                        ],
                      );
                      return compact
                          ? Column(
                              children: [avatarSection, fields],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: fields),
                                const SizedBox(width: 22),
                                avatarSection,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: returnLocation,
                    decoration: fieldDecoration('Primary Return Location'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Xarunta Gor Gor',
                        child: Text('Xarunta Gor Gor'),
                      ),
                      DropdownMenuItem(
                        value: 'Xafiiska Maamulka',
                        child: Text('Xafiiska Maamulka'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      returnLocation = value ?? returnLocation;
                    }),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        try {
                          final updated = await Db.update(
                            'users',
                            currentUser!['id'],
                            {
                              'name': name.text.trim(),
                              'mobile': mobile.text.trim(),
                            },
                          );
                          final nextUser = updated is List && updated.isNotEmpty
                              ? Map<String, dynamic>.from(updated.first as Map)
                              : {
                                  ...currentUser!,
                                  'name': name.text.trim(),
                                  'mobile': mobile.text.trim(),
                                };
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('userData', jsonEncode(nextUser));
                          if (mounted) setState(() => currentUser = nextUser);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          _showSnackBar('Profile updated.', Colors.green.shade600);
                        } catch (e) {
                          _showSnackBar(
                            'Could not update profile: $e',
                            Colors.redAccent,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff155eef),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      mobile.dispose();
    });
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleLogout() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('loggedIn');
    if (mounted) {
      Navigator.pushReplacementNamed(context, LoginPage.id);
    }
  }

  void _showProductDetails(Map<String, dynamic> item) {
    final imageUrl = item['image']?.toString() ?? '';
    final specifications = _itemSpecifications(item);
    final operational = _isOperationallyAvailable(item);
    final occupied = _isItemRented(item);
    final reserved = _isItemReserved(item);
    final availability = !operational
        ? item['operationalStatus']?.toString() ?? 'Unavailable'
        : occupied
        ? _t('Rented out today', 'Maanta waa la kireystay')
        : reserved
        ? _t('Reserved for upcoming dates', 'Taariikho dambe ayaa loo qabsaday')
        : _t('Available to rent', 'Waa la kiraysan karaa');
    final accessories = _itemDetail(item, ['accessories', 'included', 'package']);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name']?.toString() ?? 'Equipment details',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff0b1b45),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xfff2f6fd),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.laptop_mac_outlined, size: 80, color: Color(0xff155eef))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '\$${item['price'] ?? '0'} / day',
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xff155eef)),
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.circle, size: 10, color: Color(0xff16955a)),
                      label: Text(availability),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                  Text(_t('Device specifications', 'Sifooyinka qalabka'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (specifications.isEmpty)
                  const Text('Specifications will be confirmed by our team.', style: TextStyle(color: Color(0xff52627e)))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specifications.map((value) => Chip(label: Text(value))).toList(),
                  ),
                const SizedBox(height: 18),
                  Text(_t('Included with your rental', 'Waxyaabaha la socda'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  accessories.isEmpty ? 'Device, charger, and standard rental support.' : accessories,
                  style: const TextStyle(color: Color(0xff52627e), height: 1.45),
                ),
                const SizedBox(height: 18),
                  Text(_t('Rental terms', 'Shuruudaha kirada'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Choose your rental dates at checkout. Please return the device and included accessories by the agreed return date.',
                  style: TextStyle(color: Color(0xff52627e), height: 1.45),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: operational
                        ? () {
                            Navigator.pop(dialogContext);
                            Future<void>.delayed(
                              Duration.zero,
                              () => _openBookingSheet(item),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(operational ? _t('Choose rental dates', 'Dooro taariikhaha kirada') : _t('Currently unavailable', 'Hadda lama heli karo')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff155eef),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBookingSheet(Map<String, dynamic> item) {
    if (!_isOperationallyAvailable(item)) {
      _showSnackBar(
        'This device is not available while it is in ${item['operationalStatus'] ?? 'maintenance'}.',
        Colors.redAccent,
      );
      return;
    }
    DateTime today = DateTime.now();
    DateTime normalizedToday = DateTime(today.year, today.month, today.day);
    DateTimeRange? selectedRange;
    double calculatedTotal =
        double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                top: 14,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child:
                            item['image'] != null &&
                                item['image'].toString().isNotEmpty
                            ? Image.network(
                                item['image'],
                                width: 85,
                                height: 85,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade100,
                                width: 85,
                                height: 85,
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? 'Premium Item',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E24),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '\$${item['price']}/day',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Select Book/Rental Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E1E24),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: normalizedToday,
                        lastDate: normalizedToday.add(
                          const Duration(days: 365),
                        ),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.deepPurple,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Color(0xFF1E1E24),
                            ),
                          ),
                          child: child!,
                        ),
                        selectableDayPredicate:
                            (day, selectedStartDay, selectedEndDay) =>
                                !_isDateUnavailable(item, day),
                      );

                      if (picked != null) {
                        setModalState(() {
                          selectedRange = picked;
                          int days = picked.duration.inDays == 0
                              ? 1
                              : picked.duration.inDays + 1;
                          double dailyPrice =
                              double.tryParse(
                                item['price']?.toString() ?? '0',
                              ) ??
                              0.0;
                          calculatedTotal = days * dailyPrice;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFF8F9FC),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.deepPurple,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              selectedRange == null
                                  ? 'Choose Your Timeline...'
                                  : '${selectedRange!.start.toIso8601String().substring(0, 10)}   →   ${selectedRange!.end.toIso8601String().substring(0, 10)}',
                              style: TextStyle(
                                color: selectedRange == null
                                    ? Colors.grey.shade600
                                    : const Color(0xFF1E1E24),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Summary',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          '\$${calculatedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: selectedRange == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            _createBooking(
                              item,
                              selectedRange!.start,
                              selectedRange!.end,
                              calculatedTotal,
                            );
                          },
                    child: Text(
                      'Place Reservation Request',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.amber.shade800;
      case 'cancelled':
        return Colors.red;
      case 'returned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 780;

    return Scaffold(
      backgroundColor: const Color(0xfff6f9ff),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: AppBar(
          titleSpacing: 16,
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leadingWidth: 54,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image.asset(
                  'images/logo.jpeg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_t('Hello', 'Salaan')}, ${currentUser?['name'] ?? "User"} 👋',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xff0b1b45),
                ),
              ),
              Text(
                _t('Rent smart. Work better.', 'Si fudud u kirayso. Si fiican u shaqee.'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff52627e),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<bool>(
              tooltip: _t('Language', 'Luqad'),
              icon: const Icon(Icons.language_outlined, color: Color(0xff155eef)),
              onSelected: _setLanguage,
              itemBuilder: (context) => [
                PopupMenuItem(value: false, child: Text('English${!_isSomali ? ' ✓' : ''}')),
                PopupMenuItem(value: true, child: Text('Soomaali${_isSomali ? ' ✓' : ''}')),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xff155eef),
                  ),
                  onPressed: _openNotifications,
                  tooltip: _t('Booking updates', 'Wararka booking-ka'),
                ),
                if (_notifications.isNotEmpty)
                  Positioned(
                    top: 14,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xff155eef),
              ),
              onPressed: _openProfile,
              tooltip: _t('My profile', 'Profile-kayga'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xff155eef),
                ),
                onPressed: _handleLogout,
                tooltip: _t('Sign out', 'Ka bax'),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xff155eef),
                strokeWidth: 3,
              ),
            )
          : RefreshIndicator(
              color: const Color(0xff155eef),
              onRefresh: _loadUserAndData,
              child: switch (_currentIndex) {
                0 => _buildExploreTab(compact),
                1 => _buildActiveRentalsTab(),
                _ => _buildMyBookingsTab(),
              },
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xff155eef),
          unselectedItemColor: const Color(0xff8b95a8),
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.dashboard_outlined, size: 22),
              ),
              activeIcon: Icon(Icons.dashboard_rounded, size: 22),
              label: _t('Discover', 'Raadi'),
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.receipt_long_outlined, size: 22),
              ),
              activeIcon: Icon(Icons.receipt_long_rounded, size: 22),
              label: _t('Active Rentals', 'Kirada socota'),
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.history_outlined, size: 22),
              ),
              activeIcon: Icon(Icons.history_rounded, size: 22),
              label: _t('My Bookings', 'Booking-yadayda'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool compact) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xffeaf2ff)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              compact
                  ? _buildHeroText()
                  : Expanded(flex: 5, child: _buildHeroText()),
              SizedBox(width: compact ? 0 : 28, height: compact ? 20 : 0),
              compact
                  ? _buildHeroImage()
                  : Expanded(flex: 5, child: _buildHeroImage()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroText() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _t('RENT SMART. WORK BETTER.', 'SI FUDUD U KIRAYSO. SI FIICAN U SHAQEE.'),
        style: const TextStyle(
          color: Color(0xff155eef),
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        _t('The right device for your next big idea.', 'Qalabka saxda ah ee fikraddaada weyn.'),
        style: const TextStyle(
          fontSize: 34,
          height: 1.08,
          letterSpacing: -1.3,
          fontWeight: FontWeight.w800,
          color: Color(0xff0b1b45),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        _t(
          'Study for exams, finish your assignment, build your business, or work from anywhere with a dependable laptop or desktop rented for the days you need.',
          'U diyaargarow imtixaanka, dhammee shaqadaada, dhis ganacsigaaga, ama meel kasta ka shaqee adigoo kiraysanaya laptop ama desktop tayo leh.',
        ),
        style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xff52627e)),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildHeroTag(Icons.school_outlined, _t('Study-ready', 'Waxbarasho diyaar')),
          _buildHeroTag(Icons.work_outline_rounded, _t('Work faster', 'Shaqo degdeg ah')),
          _buildHeroTag(Icons.payments_outlined, _t('Pay per day', 'Maalintii bixi')),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildPrimaryButton(
            _t('Browse rentals', 'Eeg qalabka kirada'),
            _browseRentals,
          ),
        ],
      ),
    ],
  );

  Widget _buildHeroImage() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&w=1200&q=85',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Color(0x99061d55), Colors.transparent],
              ),
            ),
          ),
          const Positioned(
            left: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POWER FOR EVERY TASK',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Premium equipment, ready today',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeroTag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.8),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xffd8e4ff)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xff155eef), size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xff26334e),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildBenefits() => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: const [
          _Benefit(
            Icons.verified_user_outlined,
            'Trusted & reliable',
            'Quality checked devices',
          ),
          _Benefit(
            Icons.payments_outlined,
            'Fair pricing',
            'Simple daily rates',
          ),
          _Benefit(
            Icons.calendar_month_outlined,
            'Flexible rental',
            'Book for any timeline',
          ),
          _Benefit(
            Icons.support_agent_outlined,
            '24/7 support',
            'We are here to help',
          ),
        ],
      ),
    ),
  );

  Widget _buildSectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Color(0xff0b1b45),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xff52627e), fontSize: 14),
        ),
      ],
    ),
  );

  Widget _buildPrimaryButton(String text, VoidCallback callback) =>
      ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff155eef),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  String _ramDetail(Map<String, dynamic> item) {
    final details = item['details']?.toString() ?? '';
    final ramMatch = RegExp(
      r'(?:ram|memory)\s*[:\-]?\s*(\d+(?:\.\d+)?\s*(?:gb|mb|kb))|'
      r'(\d+(?:\.\d+)?\s*(?:gb|mb|kb))\s*(?:ram|memory)',
      caseSensitive: false,
    ).firstMatch(details);
    final value = ramMatch?.group(1) ?? ramMatch?.group(2);
    return value == null ? 'RAM: Not specified' : 'RAM: ${value.trim()}';
  }

  String _itemDetail(Map<String, dynamic> item, List<String> keys) {
    final details = item['details']?.toString() ?? '';
    final itemFields = <String, dynamic>{};
    for (final entry in item.entries) {
      itemFields[entry.key.toLowerCase()] = entry.value;
    }
    for (final key in keys) {
      final directValue = itemFields[key.toLowerCase()]?.toString().trim();
      if (directValue != null && directValue.isNotEmpty) return directValue;
      final match = RegExp(
        '${RegExp.escape(key)}\\s*[:\\-]\\s*([^|;]+)',
        caseSensitive: false,
      ).firstMatch(details);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  List<String> _itemSpecifications(Map<String, dynamic> item) {
    final fields = <MapEntry<String, List<String>>>[
      MapEntry('Type', ['type', 'category']),
      MapEntry('Processor', ['processor', 'cpu']),
      MapEntry('RAM', ['ram', 'memory']),
      MapEntry('Storage', ['storage', 'ssd', 'disk']),
      MapEntry('Screen', ['screen', 'display']),
    ];
    return fields
        .map((field) {
          final value = _itemDetail(item, field.value);
          return value.isEmpty ? '' : '${field.key}: $value';
        })
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Widget _buildExploreTab(bool compact) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_clear_outlined,
              size: 54,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            const Text(
              'No available products listed yet.',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final prices = items
        .map((item) => double.tryParse(item['price']?.toString() ?? '0') ?? 0)
        .toList();
    final lowestPrice = prices.reduce((a, b) => a < b ? a : b);
    const sliderMax = 150.0;
    final selectedPriceRange =
        _priceRange ?? RangeValues(lowestPrice, sliderMax);
    final filteredItems = items.where((item) {
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final searchableText = '${item['name'] ?? ''} ${item['details'] ?? ''}'
          .toLowerCase();
      final categoryTerm = switch (_selectedCategory) {
        'Laptops' => 'laptop',
        'Desktops' => 'desktop',
        'Workstations' => 'workstation',
        'Accessories' => 'accessor',
        _ => '',
      };
      final categoryMatches =
          categoryTerm.isEmpty || searchableText.contains(categoryTerm);
      final ramMatches = switch (_selectedRam) {
        '8GB' => searchableText.contains('8gb'),
        '16GB' => searchableText.contains('16gb'),
        '32GB+' =>
          searchableText.contains('32gb') || searchableText.contains('64gb'),
        _ => true,
      };
      return price >= selectedPriceRange.start &&
          price <= selectedPriceRange.end &&
          searchableText.contains(_deviceSearchQuery) &&
          categoryMatches &&
          ramMatches;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          _buildHeroSection(compact),
          ConstrainedBox(
            key: _discoverDevicesKey,
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Discover Devices', 'Raadi Qalabka'),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff0b1b45),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xfff0eff5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_t('Price per day', 'Qiimaha maalintii')}: \$${selectedPriceRange.start.toStringAsFixed(0)} – \$${selectedPriceRange.end.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xff26334e),
                          ),
                        ),
                        RangeSlider(
                          values: selectedPriceRange,
                          min: lowestPrice,
                          max: sliderMax,
                          divisions: (sliderMax - lowestPrice)
                              .round()
                              .clamp(1, 100)
                              .toInt(),
                          labels: RangeLabels(
                            '\$${selectedPriceRange.start.toStringAsFixed(0)}',
                            '\$${selectedPriceRange.end.toStringAsFixed(0)}',
                          ),
                          onChanged: (values) =>
                              setState(() => _priceRange = values),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _deviceSearchController,
                    onChanged: (value) => setState(
                      () => _deviceSearchQuery = value.trim().toLowerCase(),
                    ),
                    decoration: InputDecoration(
                      hintText: _t('Search for: elitebook, MacBook, etc.', 'Raadi: elitebook, MacBook, iwm.'),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xff52627e),
                      ),
                      suffixIcon: _deviceSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _deviceSearchController.clear();
                                setState(() => _deviceSearchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffdce3ef)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffdce3ef)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildFilterGroup(
                        _t('Category', 'Qaybta'),
                        ['All', 'Laptops', 'Desktops'],
                        _selectedCategory,
                        (value) => setState(() => _selectedCategory = value),
                      ),
                      _buildFilterGroup(
                        'RAM',
                        ['All', '8GB', '16GB', '32GB+'],
                        _selectedRam,
                        (value) => setState(() => _selectedRam = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _t('Popular devices', 'Qalabka caanka ah'),
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xff0b1b45),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _isSomali
                              ? '${filteredItems.length} qalab ayaa waafaqaya filter-radaada.'
                              : '${filteredItems.length} device(s) match your filters.',
                          style: const TextStyle(
                            color: Color(0xff52627e),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth < 560
                          ? 1
                          : constraints.maxWidth < 900
                          ? 2
                          : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredItems.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: compact ? .86 : .82,
                        ),
                        itemBuilder: (context, index) {
                          final item = Map<String, dynamic>.from(
                            filteredItems[index] as Map,
                          );
                          final itemSpecifications = _itemSpecifications(item);
                          final String? imgUrl = item['image'];
                          final bool isOccupied = _isItemRented(item);
                          final bool isReserved = _isItemReserved(item);
                          final bool isOperational = _isOperationallyAvailable(
                            item,
                          );
                          final String availabilityLabel = !isOperational
                              ? _t(
                                  item['operationalStatus']?.toString() ?? 'Unavailable',
                                  'Lama heli karo',
                                )
                              : isOccupied
                              ? _t('Rented Out', 'La kireystay')
                              : isReserved
                              ? _t('Reserved', 'La sii qabsaday')
                              : _t('Available', 'La heli karo');

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xffe5ebf4),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: compact ? 190 : 250,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            child:
                                                imgUrl != null &&
                                                    imgUrl.isNotEmpty
                                                ? Image.network(
                                                    imgUrl,
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                  )
                                                : Container(
                                                    color: const Color(
                                                      0xffedf3ff,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.laptop_mac_outlined,
                                                      color: Color(0xff155eef),
                                                      size: 48,
                                                    ),
                                                  ),
                                          ),
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: !isOperational
                                                    ? Colors.orange.shade700
                                                          .withOpacity(0.9)
                                                    : isOccupied
                                                    ? Colors.red.shade600
                                                          .withOpacity(0.9)
                                                    : isReserved
                                                    ? Colors.amber.shade800
                                                          .withOpacity(0.9)
                                                    : Colors.green.shade600
                                                          .withOpacity(0.9),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: Text(
                                                availabilityLabel,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item['name'] ?? 'Premium Asset',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xff0b1b45),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    itemSpecifications.isEmpty
                                        ? 'Ready to rent'
                                        : itemSpecifications.join(' | '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff6b7890),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: Color(0xff0b1b45),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '\$${item['price'] ?? "0"}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' / day',
                                          style: TextStyle(
                                            color: Color(0xff6b7890),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '★ ★ ★ ★ ★',
                                          style: TextStyle(
                                            color: Colors.amber.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _showProductDetails(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xff155eef,
                                          ),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              Colors.grey.shade300,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _t('View details', 'Eeg faahfaahinta'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
      decoration: BoxDecoration(
        color: const Color(0xfff0eff5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xff26334e),
            ),
          ),
          Wrap(
            spacing: 2,
            children: options.map((option) {
              return SizedBox(
                height: 34,
                child: ChoiceChip(
                  label: Text(option, style: const TextStyle(fontSize: 12)),
                  selected: selected == option,
                  onSelected: (_) => onChanged(option),
                  selectedColor: const Color(0xffcfe0ff),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: Colors.transparent,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRentalsTab() {
    final activeRentals = items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) => _isOperationallyAvailable(item) && !_isItemRented(item),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        const Center(
          child: Text(
            'Active Rentals',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xff0b1b45),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Your current equipment reservations',
            style: const TextStyle(color: Color(0xff52627e), fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xffe7edff),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xff155eef),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Total available devices: ${activeRentals.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xff26334e),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (activeRentals.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                'All devices are currently rented or unavailable.',
                style: TextStyle(color: Color(0xff6b7890), fontSize: 15),
              ),
            ),
          )
        else
          ...activeRentals.map((item) {
            final imageUrl = item['image']?.toString() ?? '';
            final itemSpecifications = <String>[
              if (_itemDetail(item, ['type', 'category']).isNotEmpty)
                'Type: ${_itemDetail(item, ['type', 'category'])}',
              if (_itemDetail(item, ['processor', 'cpu']).isNotEmpty)
                'Processor: ${_itemDetail(item, ['processor', 'cpu'])}',
              if (_itemDetail(item, ['ram', 'memory']).isNotEmpty)
                'RAM: ${_itemDetail(item, ['ram', 'memory'])}',
              if (_itemDetail(item, ['storage', 'ssd', 'disk']).isNotEmpty)
                'Storage: ${_itemDetail(item, ['storage', 'ssd', 'disk'])}',
              if (_itemDetail(item, ['screen', 'display']).isNotEmpty)
                'Screen: ${_itemDetail(item, ['screen', 'display'])}',
            ];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffe5ebf4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 92,
                            height: 92,
                            fit: BoxFit.contain,
                          )
                        : Container(
                            width: 92,
                            height: 92,
                            color: const Color(0xffedf3ff),
                            child: const Icon(Icons.laptop_mac_outlined),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['name']?.toString() ?? 'Equipment',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xff0b1b45),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Available',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (itemSpecifications.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            itemSpecifications.join(' | '),
                            style: const TextStyle(
                              color: Color(0xff52627e),
                              fontSize: 12,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          'Ready to rent today',
                          style: const TextStyle(
                            color: Color(0xff52627e),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Price: \$${item['price'] ?? '0'} / day',
                          style: const TextStyle(
                            color: Color(0xff155eef),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _openBookingSheet(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff155eef),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Book / Rent'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMyBookingsTab() {
    final filteredBookings = myBookings.where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      final completedStatuses = {'completed', 'returned', 'confirmed'};
      return switch (_historyFilter) {
        'Completed' => completedStatuses.contains(status),
        'Cancelled' => status == 'cancelled',
        _ => true,
      };
    }).toList();
    final visibleBookings = filteredBookings;

    if (myBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 54,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No operational logs found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your approved rental timelines will update live right here.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        const Center(
          child: Text(
            'Rental History',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xff0b1b45),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'All', label: Text('All')),
              ButtonSegment(value: 'Completed', label: Text('Completed')),
              ButtonSegment(value: 'Cancelled', label: Text('Cancelled')),
            ],
            selected: {_historyFilter},
            onSelectionChanged: (selection) => setState(() {
              _historyFilter = selection.first;
            }),
          ),
        ),
        const SizedBox(height: 16),
        if (visibleBookings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 70),
            child: Center(child: Text('No rentals match this filter.')),
          )
        else
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffdfe7f4)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xffe9eef9),
                ),
                dataRowMinHeight: 74,
                dataRowMaxHeight: 88,
                columnSpacing: 26,
                columns: const [
                  DataColumn(label: Text('DEVICE')),
                  DataColumn(label: Text('RENTAL DATES')),
                  DataColumn(label: Text('TOTAL COST')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: visibleBookings.map<DataRow>((booking) {
                  final status = booking['status']?.toString() ?? 'Pending';
                  final normalizedStatus = status.toLowerCase();
                  final displayStatus = switch (normalizedStatus) {
                    'returned' || 'completed' || 'confirmed' => 'Completed',
                    _ => status,
                  };
                  final statusColor = _getStatusColor(status);
                  final imageUrl = booking['productImage']?.toString() ?? '';
                  final canCancel =
                      (normalizedStatus == 'pending' ||
                          normalizedStatus == 'confirmed') &&
                      !((DateTime.tryParse(
                            booking['startDate']?.toString() ?? '',
                          )?.isBefore(
                            DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                            ),
                          )) ??
                          true);
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.contain,
                                    )
                                  : const Icon(
                                      Icons.laptop_mac_outlined,
                                      size: 42,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 170,
                              child: Text(
                                booking['productName']?.toString() ??
                                    'Equipment Rental',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          '${booking['startDate'] ?? '-'} to ${booking['endDate'] ?? '-'}',
                        ),
                      ),
                      DataCell(Text('\$${booking['price'] ?? '0'}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        PopupMenuButton<String>(
                          tooltip: 'Booking actions',
                          onSelected: (action) {
                            final selected = Map<String, dynamic>.from(booking);
                            if (action == 'details') _showBookingDetails(selected);
                            if (action == 'reschedule') _requestReschedule(selected);
                            if (action == 'cancel') _cancelBooking(selected);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'details', child: Text('View details')),
                            if (canCancel) ...[
                              const PopupMenuItem(value: 'reschedule', child: Text('Request new dates')),
                              const PopupMenuItem(value: 'cancel', child: Text('Cancel booking')),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Showing ${filteredBookings.length} of ${filteredBookings.length} rentals',
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _Benefit(this.icon, this.title, this.sub, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff155eef), size: 28),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xff0b1b45),
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff6b7890),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
