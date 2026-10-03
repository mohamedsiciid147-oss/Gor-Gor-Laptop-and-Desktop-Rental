import 'package:flutter/material.dart';
import '../../database/database.dart'; // Adjust path if necessary

class Items extends StatefulWidget {
  const Items({super.key});

  @override
  State<Items> createState() => _ItemsState();
}

class _ItemsState extends State<Items> {
  List<dynamic> items = [];
  List<dynamic> bookings = [];
  bool isLoading = false;
  final ScrollController _tableScrollController = ScrollController();

  // Pagination states
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    getItems();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  bool _hasActiveBookingForItem(Map<String, dynamic> item) {
    final itemId = item['id']?.toString();
    if (itemId == null || itemId.isEmpty) return false;

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return bookings.any((booking) {
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

  String _effectiveStatus(Map<String, dynamic> item) {
    final manualStatus = item['operationalStatus']?.toString().trim();
    if (manualStatus != null &&
        manualStatus.isNotEmpty &&
        manualStatus.toLowerCase() != 'available') {
      return manualStatus;
    }
    return _hasActiveBookingForItem(item) ? 'Rented Out' : 'Available';
  }

  // Fetch paginated items
  Future<void> getItems() async {
    setState(() => isLoading = true);
    try {
      int offset = (_currentPage - 1) * _pageSize;
      final result = await Future.wait([
        Db.get('items', limit: _pageSize, offset: offset),
        Db.get('bookings'),
      ]);

      final fetchedItems = result[0] is List
          ? result[0] as List<dynamic>
          : <dynamic>[];
      final fetchedBookings = result[1] is List
          ? result[1] as List<dynamic>
          : <dynamic>[];

      setState(() {
        items = fetchedItems;
        bookings = fetchedBookings;
        _hasMore = fetchedItems.length == _pageSize;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading items: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Delete item directly from database
  Future<void> deleteItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        isLoading = true;
        items.removeWhere((entry) => entry['id'] == item['id']);
      });
      try {
        await Db.delete('items', id: item['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await getItems();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void showFormDialog(Map<String, dynamic>? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ItemFormDialog(
        item: item,
        onSave: () {
          Navigator.pop(context);
          getItems();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurple,
                      ),
                    )
                  : items.isEmpty
                  ? const Center(child: Text('No records found in this table.'))
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _tableScrollController,
                            primary: false,
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
                                          Color(0xfff5f2ff),
                                        ),
                                    dataRowColor: const WidgetStatePropertyAll(
                                      Colors.white,
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
                                      DataColumn(label: Text('NAME')),
                                      DataColumn(label: Text('BRAND')),
                                      DataColumn(label: Text('SERIAL')),
                                      DataColumn(label: Text('STATUS')),
                                      DataColumn(label: Text('PRICE')),
                                      DataColumn(label: Text('DETAILS')),
                                      DataColumn(label: Text('ACTIONS')),
                                    ],
                                    rows: items.map<DataRow>((item) {
                                      String? imageUrl = item['image'];
                                      String rawDetails =
                                          item['details']?.toString() ?? '-';
                                      String shortDetails =
                                          rawDetails.length > 20
                                          ? '${rawDetails.substring(0, 20)}...'
                                          : rawDetails;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child:
                                                  imageUrl != null &&
                                                      imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      width: 40,
                                                      height: 40,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.grey,
                                                            size: 20,
                                                          ),
                                                    )
                                                  : Container(
                                                      color:
                                                          Colors.grey.shade100,
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
                                            Text(
                                              item['name']?.toString() ?? '-',
                                              overflow: TextOverflow.ellipsis,
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
                                                color: const Color(0xffeffcf5),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xffa7e6c6,
                                                  ),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item['brand']?.toString() ??
                                                    '-',
                                                style: const TextStyle(
                                                  color: Color(0xff159553),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              item['serialNumber']
                                                      ?.toString() ??
                                                  '-',
                                            ),
                                          ),
                                          DataCell(
                                            _statusChip(
                                              _effectiveStatus(
                                                Map<String, dynamic>.from(item),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '\$${item['price']?.toString() ?? '0'}',
                                              style: const TextStyle(
                                                color: Color(0xff3e24d2),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              shortDetails,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () =>
                                                      showFormDialog(item),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(
                                                      4.0,
                                                    ),
                                                    child: Icon(
                                                      Icons.edit_outlined,
                                                      color: Color(0xff4d2ee5),
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () => deleteItem(item),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(
                                                      4.0,
                                                    ),
                                                    child: Icon(
                                                      Icons.delete_outline,
                                                      color: Color(0xffef3434),
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                              getItems();
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
                                              getItems();
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4429d0),
        foregroundColor: Colors.white,
        onPressed: () => showFormDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'maintenance' => Colors.orange,
      'damaged' => Colors.red,
      'retired' => Colors.grey,
      'rented out' => Colors.red,
      _ => Colors.green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

// --- ITEM FORM DIALOG USING WEB URL STRINGS ---
class ItemFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final VoidCallback onSave;

  const ItemFormDialog({super.key, this.item, required this.onSave});

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _detailsController;
  late TextEditingController _processorController;
  late TextEditingController _ramController;
  late TextEditingController _storageController;
  late TextEditingController _screenController;
  late TextEditingController _imageUrlController;
  late TextEditingController _serialNumberController;
  late TextEditingController _maintenanceNotesController;
  late TextEditingController _lastMaintenanceDateController;
  late TextEditingController _nextMaintenanceDateController;
  late TextEditingController _maintenanceCostController;
  String _operationalStatus = 'Available';
  String _deviceType = 'Laptop';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.item?['name']?.toString() ?? '',
    );
    _brandController = TextEditingController(
      text: widget.item?['brand']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.item?['price']?.toString() ?? '',
    );
    _detailsController = TextEditingController(
      text: widget.item?['details']?.toString() ?? '',
    );
    final specificationFields = _parseSpecificationFields(
      widget.item?['details']?.toString() ?? '',
    );
    _processorController = TextEditingController(
      text: specificationFields['processor'] ?? '',
    );
    _ramController = TextEditingController(
      text: specificationFields['ram'] ?? '',
    );
    _storageController = TextEditingController(
      text: specificationFields['storage'] ?? '',
    );
    _screenController = TextEditingController(
      text: specificationFields['screen'] ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.item?['image']?.toString() ?? '',
    );
    _serialNumberController = TextEditingController(
      text: widget.item?['serialNumber']?.toString() ?? '',
    );
    _maintenanceNotesController = TextEditingController(
      text: widget.item?['maintenanceNotes']?.toString() ?? '',
    );
    _lastMaintenanceDateController = TextEditingController(
      text: widget.item?['lastMaintenanceDate']?.toString() ?? '',
    );
    _nextMaintenanceDateController = TextEditingController(
      text: widget.item?['nextMaintenanceDate']?.toString() ?? '',
    );
    _maintenanceCostController = TextEditingController(
      text: widget.item?['maintenanceCost']?.toString() ?? '',
    );
    _operationalStatus =
        widget.item?['operationalStatus']?.toString() ?? 'Available';
    _deviceType = _inferDeviceType(
      widget.item?['name']?.toString() ?? '',
      widget.item?['details']?.toString() ?? '',
    );

    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _detailsController.dispose();
    _processorController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    _screenController.dispose();
    _serialNumberController.dispose();
    _maintenanceNotesController.dispose();
    _lastMaintenanceDateController.dispose();
    _nextMaintenanceDateController.dispose();
    _maintenanceCostController.dispose();
    super.dispose();
  }

  Future<void> _pickMaintenanceDate(TextEditingController controller) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
    );
    if (selected != null) {
      setState(() {
        controller.text = selected.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final details = _composeDetails();
      Map<String, dynamic> payload = {
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'details': details,
        'image': _imageUrlController.text.trim(),
        'bookedDate': widget.item?['bookedDate'],
        'userId': widget.item?['userId'],
        'serialNumber': _serialNumberController.text.trim(),
        'operationalStatus': _operationalStatus,
        'maintenanceNotes': _maintenanceNotesController.text.trim(),
        'lastMaintenanceDate': _lastMaintenanceDateController.text.trim().isEmpty
            ? null
            : _lastMaintenanceDateController.text.trim(),
        'nextMaintenanceDate': _nextMaintenanceDateController.text.trim().isEmpty
            ? null
            : _nextMaintenanceDateController.text.trim(),
        'maintenanceCost': double.tryParse(_maintenanceCostController.text.trim()),
      };

      if (widget.item == null) {
        await Db.post('items', payload);
      } else {
        payload['id'] = widget.item!['id'];
        await Db.update('items', widget.item!['id'], payload);
      }

      widget.onSave();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _inferDeviceType(String name, String details) {
    final text = '$name $details'.toLowerCase();
    if (text.contains('desktop') || text.contains('workstation')) {
      return 'Desktop';
    }
    return 'Laptop';
  }

  Map<String, String> _parseSpecificationFields(String details) {
    final fields = <String, String>{};
    for (final part in details.split('|')) {
      final separator = part.indexOf(':');
      if (separator < 0) continue;
      final label = part.substring(0, separator).trim().toLowerCase();
      final value = part.substring(separator + 1).trim();
      if (value.isEmpty) continue;
      if (label == 'processor' || label == 'cpu') fields['processor'] = value;
      if (label == 'ram' || label == 'memory') fields['ram'] = value;
      if (label == 'storage' || label == 'ssd' || label == 'disk') {
        fields['storage'] = value;
      }
      if (label == 'screen' || label == 'display') fields['screen'] = value;
    }

    if (!fields.containsKey('processor')) {
      final processor = RegExp(
        r'((?:intel|amd|apple)[^,|]*(?:core|ryzen|m[1-4])[^,|]*)',
        caseSensitive: false,
      ).firstMatch(details);
      if (processor != null) fields['processor'] = processor.group(1)!.trim();
    }
    if (!fields.containsKey('ram')) {
      final ram = RegExp(
        r'(\d{1,3}\s*gb\s*(?:ram|memory)?)',
        caseSensitive: false,
      ).firstMatch(details);
      if (ram != null) fields['ram'] = ram.group(1)!.trim();
    }
    if (!fields.containsKey('storage')) {
      final storage = RegExp(
        r'(\d{3,4}\s*(?:gb|tb)\s*(?:ssd|hdd|storage|disk)?)',
        caseSensitive: false,
      ).firstMatch(details);
      if (storage != null) fields['storage'] = storage.group(1)!.trim();
    }
    return fields;
  }

  String _composeDetails() {
    final specifications = <String>['Type: $_deviceType'];
    final values = <String, String>{
      'Processor': _processorController.text.trim(),
      'RAM': _ramController.text.trim(),
      'Storage': _storageController.text.trim(),
      'Screen': _screenController.text.trim(),
    };
    values.forEach((label, value) {
      if (value.isNotEmpty) specifications.add('$label: $value');
    });
    final notes = _detailsController.text.trim();
    if (notes.isNotEmpty && !notes.contains(':')) specifications.add(notes);
    return specifications.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item == null
                    ? 'Create Item Entry'
                    : 'Update Item Details',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageUrlController.text.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            _imageUrlController.text.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 30,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Invalid URL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 30,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Live Preview',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Web Image URL String',
                  hintText: 'https://images.unsplash.com/...',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter an image URL link'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Field required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Field required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (\$)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Field required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _deviceType,
                decoration: const InputDecoration(
                  labelText: 'Device type',
                  border: OutlineInputBorder(),
                ),
                items: const ['Laptop', 'Desktop']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (type) =>
                    setState(() => _deviceType = type ?? 'Laptop'),
              ),
              const SizedBox(height: 16),
              Text(
                'Verified specifications',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _processorController,
                      decoration: const InputDecoration(
                        labelText: 'Processor / CPU',
                        hintText: 'e.g. Intel Core i5-1240P',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ramController,
                      decoration: const InputDecoration(
                        labelText: 'RAM',
                        hintText: 'e.g. 8 GB',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _storageController,
                      decoration: const InputDecoration(
                        labelText: 'Storage',
                        hintText: 'e.g. 512 GB SSD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _screenController,
                      decoration: const InputDecoration(
                        labelText: 'Screen / Display',
                        hintText: 'e.g. 24-inch Full HD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serialNumberController,
                decoration: const InputDecoration(
                  labelText: 'Serial Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _operationalStatus,
                decoration: const InputDecoration(
                  labelText: 'Equipment condition',
                  border: OutlineInputBorder(),
                ),
                items: const ['Available', 'Maintenance', 'Damaged', 'Retired']
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (status) =>
                    setState(() => _operationalStatus = status ?? 'Available'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional verified notes',
                  hintText: 'Only add facts confirmed for this device',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _maintenanceNotesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Maintenance / damage notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lastMaintenanceDateController,
                      readOnly: true,
                      onTap: () => _pickMaintenanceDate(_lastMaintenanceDateController),
                      decoration: const InputDecoration(
                        labelText: 'Last maintenance date',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nextMaintenanceDateController,
                      readOnly: true,
                      onTap: () => _pickMaintenanceDate(_nextMaintenanceDateController),
                      decoration: const InputDecoration(
                        labelText: 'Next maintenance date',
                        suffixIcon: Icon(Icons.event_repeat_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maintenanceCostController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Maintenance cost',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving ? null : _handleSubmit,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.item == null ? 'Save Record' : 'Apply Changes',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
