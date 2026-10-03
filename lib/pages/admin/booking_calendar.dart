import 'package:flutter/material.dart';

import '../../database/database.dart';

class BookingCalendar extends StatefulWidget {
  const BookingCalendar({super.key});

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<dynamic> _bookings = [];
  bool _loading = true;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final bookings = await Db.get('bookings', order: 'id.desc');
      if (mounted) setState(() => _bookings = bookings);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load calendar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> _bookingsFor(DateTime day) => _bookings
      .whereType<Map>()
      .map((booking) => Map<String, dynamic>.from(booking))
      .where((booking) {
        final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
        final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
        return start != null && end != null && !day.isBefore(start) && !day.isAfter(end);
      })
      .toList();

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'returned': return Colors.blue;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final selectedBookings = _bookingsFor(_selectedDay);

    final selectedDateText = '${_selectedDay.day.toString().padLeft(2, '0')}/${_selectedDay.month.toString().padLeft(2, '0')}/${_selectedDay.year}';

    return Padding(
      padding: const EdgeInsets.all(26),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Booking calendar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Select any day to view scheduled rentals.', style: TextStyle(color: Color(0xff6b7194))),
                ])),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDay,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (context, child) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 440),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xff155eef),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Color(0xFF1E1E24),
                              ),
                            ),
                            child: child!,
                          ),
                        ),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDay = picked;
                        _month = DateTime(picked.year, picked.month);
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xffeaf2ff),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffdfe8ff)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xff155eef)),
                        const SizedBox(width: 8),
                        Text(selectedDateText, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xff155eef))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
                Text('${_monthNames[_month.month - 1]} ${_month.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
                IconButton(onPressed: _loadBookings, icon: const Icon(Icons.refresh)),
              ]),
              const SizedBox(height: 18),
              const Row(children: [
                Expanded(child: Center(child: Text('Sun'))), Expanded(child: Center(child: Text('Mon'))), Expanded(child: Center(child: Text('Tue'))), Expanded(child: Center(child: Text('Wed'))), Expanded(child: Center(child: Text('Thu'))), Expanded(child: Center(child: Text('Fri'))), Expanded(child: Center(child: Text('Sat'))),
              ]),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                
                  itemCount: firstWeekday + daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1.45),
                  itemBuilder: (context, index) {
                    if (index < firstWeekday) return const SizedBox();
                    final day = DateTime(_month.year, _month.month, index - firstWeekday + 1);
                    final bookings = _bookingsFor(day);
                    final selected = _sameDay(day, _selectedDay);
                    return InkWell(
                      onTap: () => setState(() => _selectedDay = day),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xff155eef) : bookings.isNotEmpty ? const Color(0xffeaf2ff) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? const Color(0xff155eef) : const Color(0xffe3e8f2)),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${day.day}', style: TextStyle(color: selected ? Colors.white : const Color(0xff0b1b45), fontWeight: FontWeight.bold)),
                          if (bookings.isNotEmpty) Container(margin: const EdgeInsets.only(top: 4), 
                          width: 7, height: 7, decoration: BoxDecoration(color: selected ? Colors.white : Colors.orange, shape: BoxShape.circle)),
                        ]),
                      ),
                    );
                  },
              ),
              const SizedBox(height: 12),
              Text('Bookings on ${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              selectedBookings.isEmpty
                    ? const Center(child: Text('No bookings scheduled for this day.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: selectedBookings.length,
                        itemBuilder: (context, index) {
                          final booking = selectedBookings[index];
                          final status = booking['status']?.toString() ?? 'Pending';
                          return Card(child: ListTile(
                            leading: CircleAvatar(backgroundColor: _statusColor(status).withOpacity(.12), child: Icon(Icons.calendar_today_outlined, color: _statusColor(status))),
                            title: Text(booking['productName']?.toString() ?? 'Rental item'),
                            subtitle: Text('${booking['user_name'] ?? 'Customer'} • ${booking['startDate']} to ${booking['endDate']}'),
                            trailing: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold)),
                          ));
                        },
                      ),
            ],
          ),
    );
  }
}
