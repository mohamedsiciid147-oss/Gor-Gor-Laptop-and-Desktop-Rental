import 'dart:async';

import 'package:flutter/material.dart';
import '../../database/database.dart'; // Adjust path if necessary

class Bookings extends StatefulWidget {
  const Bookings({super.key, this.focusedBooking, this.onClearFocusedBooking});

  final Map<String, dynamic>? focusedBooking;
  final VoidCallback? onClearFocusedBooking;

  @override
  State<Bookings> createState() => _BookingsState();
}

class _BookingsState extends State<Bookings> {
  List<dynamic> bookings = [];
  bool isLoading = false;

  // Search filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination states
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    getBookings();
    _refreshTimer = Timer.periodic(const Duration(seconds: 24), (_) {
      if (mounted) getBookings();
    });
  }

  @override
  void didUpdateWidget(covariant Bookings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedBooking?['id']?.toString() !=
        widget.focusedBooking?['id']?.toString()) {
      getBookings();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Fetch paginated and filtered bookings from database
  Future<void> getBookings() async {
    setState(() => isLoading = true);
    try {
      final focusedBookingId = widget.focusedBooking?['id'];
      final List<dynamic> fetchedBookings;
      if (focusedBookingId != null) {
        final booking = await Db.get('bookings', id: focusedBookingId);
        fetchedBookings = booking is Map ? [booking] : <dynamic>[];
      } else {
        final offset = (_currentPage - 1) * _pageSize;
        fetchedBookings = await Db.get(
          'bookings',
          limit: _pageSize,
          offset: offset,
          order: 'id.desc',
        );
      }

      setState(() {
        bookings = fetchedBookings;
        _hasMore =
            widget.focusedBooking == null && fetchedBookings.length == _pageSize;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Update booking operational status (e.g., Pending, Confirmed, Cancelled)
  Future<void> updateBookingStatus(
    Map<String, dynamic> booking,
    String newStatus,
  ) async {
    setState(() => isLoading = true);
    try {
      Map<String, dynamic> updatedPayload = Map<String, dynamic>.from(booking);
      updatedPayload['status'] = newStatus;

      await Db.update('bookings', booking['id'], updatedPayload);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking marked as $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      getBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _recordHandover(
    Map<String, dynamic> booking, {
    required bool isReturn,
  }) async {
    final notesController = TextEditingController(
      text: isReturn ? booking['returnNotes']?.toString() ?? '' : booking['checkoutNotes']?.toString() ?? '',
    );
    final conditionController = TextEditingController(
      text: booking['returnCondition']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isReturn ? 'Record equipment return' : 'Record equipment pickup'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isReturn ? 'Return notes' : 'Pickup notes',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (isReturn) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: conditionController,
                  decoration: const InputDecoration(
                    labelText: 'Equipment condition',
                    hintText: 'e.g. Inspected and approved',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(isReturn ? 'Confirm return' : 'Confirm pickup')),
        ],
      ),
    );
    if (saved != true) {
      notesController.dispose();
      conditionController.dispose();
      return;
    }
    try {
      final now = DateTime.now().toIso8601String();
      await Db.update('bookings', booking['id'], {
        if (isReturn) ...{
          'status': 'Returned',
          'returnAt': now,
          'returnNotes': notesController.text.trim(),
          'returnCondition': conditionController.text.trim(),
        } else ...{
          'pickupAt': now,
          'checkoutNotes': notesController.text.trim(),
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isReturn ? 'Return recorded.' : 'Pickup recorded.'), backgroundColor: Colors.green),
        );
      }
      getBookings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.red));
    } finally {
      notesController.dispose();
      conditionController.dispose();
    }
  }

  Future<void> _processReschedule(Map<String, dynamic> booking, bool approve) async {
    try {
      final payload = <String, dynamic>{
        'rescheduleStatus': approve ? 'Approved' : 'Rejected',
      };
      if (approve) {
        payload['startDate'] = booking['rescheduleStartDate'];
        payload['endDate'] = booking['rescheduleEndDate'];
        payload['price'] = booking['reschedulePrice'] ?? booking['price'];
      }
      await Db.update('bookings', booking['id'], payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'New dates approved.' : 'Date-change request rejected.'), backgroundColor: Colors.green));
      getBookings();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not process request: $e'), backgroundColor: Colors.red));
    }
  }

  // Soft helper decoration color matching for order status tags
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
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
    // Frontend filter logic checking fields including the new customer name row
    final filteredBookings = bookings.where((booking) {
      final productName =
          booking['productName']?.toString().toLowerCase() ?? '';
      final userId = booking['userId']?.toString().toLowerCase() ?? '';
      final userName = booking['user_name']?.toString().toLowerCase() ?? '';

      return productName.contains(_searchQuery) ||
          userId.contains(_searchQuery) ||
          userName.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.focusedBooking != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xfffff4cc),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xfff5c451)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: Color(0xffb54708)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Viewing selected request from ${widget.focusedBooking!['user_name'] ?? 'Customer'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClearFocusedBooking,
                      child: const Text('Show all bookings'),
                    ),
                  ],
                ),
              ),
            // Search Field Input Bar
            Container(
              constraints: const BoxConstraints(maxWidth: 460),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Product, User ID, or Name...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Main Responsive Content Card Panel
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurple,
                      ),
                    )
                  : filteredBookings.isEmpty
                  ? const Center(
                      child: Text('No matching reservation logs found.'),
                    )
                  : Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xffe7e6ed)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      headingRowColor:
                                          const WidgetStatePropertyAll(
                                            Color(0xfff7f6fc),
                                          ),
                                      dataRowColor:
                                          const WidgetStatePropertyAll(
                                            Color(0xfffbfaff),
                                          ),
                                      headingTextStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff4225d4),
                                      ),
                                      dataTextStyle: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xff171a3c),
                                      ),
                                      horizontalMargin: 16,
                                      columnSpacing: 16,
                                      headingRowHeight: 60,
                                      dataRowMinHeight: 56,
                                      dataRowMaxHeight: 64,
                                      columns: const [
                                        DataColumn(label: Text('IMG')),
                                        DataColumn(label: Text('PRODUCT')),
                                        DataColumn(label: Text('USER ID')),
                                        DataColumn(label: Text('CUSTOMER')),
                                        DataColumn(label: Text('START')),
                                        DataColumn(label: Text('END')),
                                        DataColumn(label: Text('PRICE')),
                                        DataColumn(label: Text('STATUS')),
                                        DataColumn(label: Text('ACTIONS')),
                                      ],
                                      rows: filteredBookings.map<DataRow>((
                                        booking,
                                      ) {
                                        String? imgUrl =
                                            booking['productImage'];
                                        String currentStatus =
                                            booking['status']?.toString() ??
                                            'Pending';
                                        final isFocusedBooking =
                                            widget.focusedBooking?['id']
                                                ?.toString() ==
                                            booking['id']?.toString();

                                        return DataRow(
                                          color: isFocusedBooking
                                              ? const WidgetStatePropertyAll(
                                                  Color(0xfffff4cc),
                                                )
                                              : null,
                                          cells: [
                                            DataCell(
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child:
                                                    imgUrl != null &&
                                                        imgUrl.isNotEmpty
                                                    ? Image.network(
                                                        imgUrl,
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              __,
                                                              ___,
                                                            ) => const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.grey,
                                                              size: 20,
                                                            ),
                                                      )
                                                    : Container(
                                                        color: Colors
                                                            .grey
                                                            .shade100,
                                                        width: 40,
                                                        height: 40,
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.grey,
                                                          size: 20,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            DataCell(
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    booking['productName']?.toString() ?? 'Unknown Item',
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (booking['rescheduleStatus']?.toString().toLowerCase() == 'pending')
                                                    Text(
                                                      'New dates: ${booking['rescheduleStartDate']} → ${booking['rescheduleEndDate']}',
                                                      style: const TextStyle(fontSize: 10, color: Color(0xffb54708)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                '#${booking['userId']?.toString() ?? '-'}',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                booking['user_name']
                                                        ?.toString() ??
                                                    'Anonymous',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                booking['startDate']
                                                        ?.toString() ??
                                                    '-',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                booking['endDate']
                                                        ?.toString() ??
                                                    '-',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                '\$${booking['price']?.toString() ?? '0'}',
                                                style: const TextStyle(
                                                  color: Color(0xff3e24d2),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                    currentStatus,
                                                  ).withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: _getStatusColor(
                                                      currentStatus,
                                                    ).withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  currentStatus,
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                      currentStatus,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, color: Colors.deepPurple),
                                                onSelected: (action) {
                                                  if (action == 'pickup') _recordHandover(Map<String, dynamic>.from(booking), isReturn: false);
                                                  if (action == 'return') _recordHandover(Map<String, dynamic>.from(booking), isReturn: true);
                                                  if (action == 'approveReschedule') _processReschedule(Map<String, dynamic>.from(booking), true);
                                                  if (action == 'rejectReschedule') _processReschedule(Map<String, dynamic>.from(booking), false);
                                                  if (action.startsWith('status:')) updateBookingStatus(Map<String, dynamic>.from(booking), action.substring(7));
                                                },
                                                itemBuilder: (context) => [
                                                  if (currentStatus.toLowerCase() != 'pending' && currentStatus.toLowerCase() != 'returned') const PopupMenuItem(value: 'status:Pending', child: Text('Mark as pending')),
                                                  if (currentStatus.toLowerCase() == 'pending') const PopupMenuItem(value: 'status:Confirmed', child: Text('Confirm booking')),
                                                  if (currentStatus.toLowerCase() == 'confirmed' && booking['pickupAt'] == null) const PopupMenuItem(value: 'pickup', child: Text('Record pickup')),
                                                  if (currentStatus.toLowerCase() == 'confirmed') const PopupMenuItem(value: 'return', child: Text('Record return')),
                                                  if (booking['rescheduleStatus']?.toString().toLowerCase() == 'pending') ...[
                                                    const PopupMenuItem(value: 'approveReschedule', child: Text('Approve new dates')),
                                                    const PopupMenuItem(value: 'rejectReschedule', child: Text('Reject new dates')),
                                                  ],
                                                  if (currentStatus.toLowerCase() != 'cancelled' && currentStatus.toLowerCase() != 'returned') const PopupMenuItem(value: 'status:Cancelled', child: Text('Cancel booking')),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // --- PAGINATION FOOTER CONTROL BAR ---
                          const Divider(height: 1, color: Color(0xffe7e6ed)),
                          Material(
                            color: const Color(0xfffbfaff),
                            elevation: 3,
                            shadowColor: const Color(0x120b1b45),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Page $_currentPage',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: _currentPage > 1
                                            ? () {
                                                setState(() => _currentPage--);
                                                getBookings();
                                              }
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: _hasMore
                                            ? () {
                                                setState(() => _currentPage++);
                                                getBookings();
                                              }
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('Next'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
