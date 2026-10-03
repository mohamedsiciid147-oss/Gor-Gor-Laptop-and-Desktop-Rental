import 'package:flutter/material.dart';

import '../../database/database.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<dynamic> _items = [];
  List<dynamic> _bookings = [];
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Future.wait([Db.get('items'), Db.get('bookings'), Db.get('users')]);
      final items = data[0] is List ? data[0] as List<dynamic> : <dynamic>[];
      final bookings = data[1] is List ? data[1] as List<dynamic> : <dynamic>[];
      final users = data[2] is List ? data[2] as List<dynamic> : <dynamic>[];

      if (mounted) {
        setState(() {
          _items = items;
          _bookings = bookings;
          _users = users;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load dashboard: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasStatus(dynamic booking, String status) =>
      booking['status']?.toString().toLowerCase() == status;

  double get _revenue => _bookings
      .where((booking) => _hasStatus(booking, 'confirmed') || _hasStatus(booking, 'returned'))
      .fold<double>(0, (sum, booking) => sum + (double.tryParse(booking['price']?.toString() ?? '0') ?? 0));

  int get _activeRentals => _bookings
      .where((booking) => _hasStatus(booking, 'pending') || _hasStatus(booking, 'confirmed'))
      .length;

  int get _cancelledBookings => _bookings
      .where((booking) => _hasStatus(booking, 'cancelled'))
      .length;

  int get _totalUsers => _users.length;

  int _bookingPriority(dynamic booking) {
    final id = booking['id'];
    final idValue = int.tryParse(id?.toString() ?? '');
    if (idValue != null) return idValue;

    final createdAt = booking['createdAt']?.toString() ??
        booking['updatedAt']?.toString() ??
        booking['startDate']?.toString() ??
        booking['endDate']?.toString() ??
        '';
    final parsed = DateTime.tryParse(createdAt);
    return parsed != null ? parsed.millisecondsSinceEpoch : 0;
  }

  bool _hasActiveBookingForItem(Map<String, dynamic> item) {
    final itemId = item['id']?.toString();
    if (itemId == null || itemId.isEmpty) return false;

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return _bookings.any((booking) {
      if (booking['itemId']?.toString() != itemId) return false;

      final status = booking['status']?.toString().toLowerCase();
      if (status != 'pending' && status != 'confirmed') return false;

      try {
        final start = DateTime.parse(booking['startDate'].toString());
        final end = DateTime.parse(booking['endDate'].toString());
        final startDay = DateTime(start.year, start.month, start.day);
        final endDay = DateTime(end.year, end.month, end.day);
        return !todayDay.isBefore(startDay) && !todayDay.isAfter(endDay);
      } catch (_) {
        return false;
      }
    });
  }

  String _effectiveItemStatus(Map<String, dynamic> item) {
    final manualStatus = item['operationalStatus']?.toString().trim();
    if (manualStatus != null &&
        manualStatus.isNotEmpty &&
        manualStatus.toLowerCase() != 'available') {
      return manualStatus;
    }
    return _hasActiveBookingForItem(item) ? 'Rented Out' : 'Available';
  }

  int get _availableItems => _items.where((item) {
        final status = _effectiveItemStatus(Map<String, dynamic>.from(item));
        return status.toLowerCase() == 'available';
      }).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final recent = [..._bookings]
      ..sort((a, b) {
        final aPriority = _bookingPriority(a);
        final bPriority = _bookingPriority(b);
        return bPriority.compareTo(aPriority);
      });
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(
            children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Business overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Live rental and inventory summary', style: TextStyle(color: Color(0xff6b7194))),
              ])),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard('Total orders', _bookings.length.toString(), Icons.receipt_long_outlined, const Color(0xff4c34b7)),
              _MetricCard('Active bookings', _activeRentals.toString(), Icons.calendar_month_outlined, const Color(0xffe98b16)),
              _MetricCard('Available devices', _availableItems.toString(), Icons.inventory_2_outlined, const Color(0xff16955a)),
              _MetricCard('Total cancellations', _cancelledBookings.toString(), Icons.cancel_outlined, const Color(0xffd95a5a)),
              _MetricCard('Total Students/Users', _totalUsers.toString(), Icons.people_outline, const Color(0xff3b82f6)),
              _MetricCard('Rental revenue', '\$${_revenue.toStringAsFixed(2)}', Icons.payments_outlined, const Color(0xff155eef)),
            ],
          ),
          const SizedBox(height: 30),
          const Text('Recent orders', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No orders yet.')))
          else
            Card(
              child: Column(
                children: recent.take(6).map<Widget>((booking) {
                  final status = booking['status']?.toString() ?? 'Pending';
                  return ListTile(
                    leading: CircleAvatar(child: Icon(_hasStatus(booking, 'confirmed') ? Icons.check : Icons.schedule)),
                    title: Text(booking['productName']?.toString() ?? 'Rental item'),
                    subtitle: Text('${booking['user_name'] ?? 'Customer'} • ${booking['startDate']} to ${booking['endDate']}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('\$${booking['price'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(status, style: const TextStyle(fontSize: 12, color: Color(0xff6b7194))),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffe7e6ed))),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Color(0xff6b7194))),
              ])),
            ]),
          ),
        ),
      );
}
