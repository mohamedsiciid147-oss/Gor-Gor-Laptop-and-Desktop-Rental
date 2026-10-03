import 'package:flutter/material.dart';
import '../../database/database.dart'; // Adjust path if necessary

class Users extends StatefulWidget {
  const Users({super.key});

  @override
  State<Users> createState() => _UsersState();
}

class _UsersState extends State<Users> {
  List<dynamic> users = [];
  bool isLoading = false;

  // Search filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination states
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    getUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch paginated users from database
  Future<void> getUsers() async {
    setState(() => isLoading = true);
    try {
      int offset = (_currentPage - 1) * _pageSize;
      List<dynamic> fetchedUsers = await Db.get(
        'users',
        limit: _pageSize,
        offset: offset,
      );

      setState(() {
        users = fetchedUsers;
        _hasMore = fetchedUsers.length == _pageSize;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Update administrative privileges or system profile permissions
  Future<void> updateUserRole(Map<String, dynamic> user, String newRole) async {
    setState(() => isLoading = true);
    try {
      Map<String, dynamic> updatedPayload = Map<String, dynamic>.from(user);
      updatedPayload['role'] = newRole;

      await Db.update('users', user['id'], updatedPayload);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['name'] ?? 'User'} updated to $newRole'),
          backgroundColor: Colors.green,
        ),
      );
      getUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to alter user privileges: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete "${user['name']}"?'),
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

    if (confirm != true) return;

    setState(() {
      isLoading = true;
      users.removeWhere((entry) => entry['id'] == user['id']);
    });

    try {
      await Db.delete('users', id: user['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      await getUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete user: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  // Visual helper color selector for management role tier tag badges
  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Colors.deepPurple;
      case 'manager':
        return Colors.blue;
      case 'user':
      case 'customer':
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Frontend search filtering evaluation row checks
    final filteredUsers = users.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final mobile = user['mobile']?.toString().toLowerCase() ?? '';

      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          mobile.contains(_searchQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Toolbar Block
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Base Directory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                onPressed: () {
                  _searchController.clear();
                  _searchQuery = '';
                  _currentPage = 1;
                  getUsers();
                },
                tooltip: 'Refresh User Database',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field Text Input Box Layout Component
          Container(
            constraints: BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
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
                hintText: 'Search by Name, Email, or Mobile...',
                prefixIcon: const Icon(Icons.person_search, color: Colors.grey),
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
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 20),

          // Main Responsive Content Card Panel Layout
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  )
                : filteredUsers.isEmpty
                ? const Center(child: Text('No matching user profiles found.'))
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('User ID')),
                                  DataColumn(label: Text('Full Name')),
                                  DataColumn(label: Text('Email Address')),
                                  DataColumn(label: Text('Mobile Phone')),
                                  DataColumn(label: Text('Account Creation')),
                                  DataColumn(label: Text('Assigned Role')),
                                  DataColumn(label: Text('Modify Access')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredUsers.map<DataRow>((user) {
                                  String currentRole =
                                      user['role']?.toString() ?? 'user';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '#${user['id']?.toString() ?? '-'}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          user['name']?.toString() ??
                                              'Unnamed User',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(user['email']?.toString() ?? '-'),
                                      ),
                                      DataCell(
                                        Text(user['mobile']?.toString() ?? '-'),
                                      ),
                                      DataCell(
                                        Text(
                                          user['created_at']
                                                  ?.toString()
                                                  .substring(0, 10) ??
                                              '-',
                                        ),
                                      ),

                                      // Colored Visual Role Badges
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(
                                              currentRole,
                                            ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: _getRoleColor(
                                                currentRole,
                                              ).withOpacity(0.5),
                                            ),
                                          ),
                                          child: Text(
                                            currentRole.toUpperCase(),
                                            style: TextStyle(
                                              color: _getRoleColor(currentRole),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Dropdown inline quick-action modifier
                                      DataCell(
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            icon: const Icon(
                                              Icons.manage_accounts,
                                              color: Colors.deepPurple,
                                            ),
                                            hint: const Text(
                                              'Role',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                            items: <String>['user', 'admin']
                                                .map((String val) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: val,
                                                    child: Text(
                                                      val.toUpperCase(),
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null &&
                                                  val != currentRole) {
                                                updateUserRole(user, val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              tooltip: 'Delete user',
                                              onPressed: () => deleteUser(user),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // --- PAGINATION FOOTER CONTROL BAR ---
                        Divider(height: 1, color: Colors.grey.shade200),
                        Padding(
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
                                            getUsers();
                                          }
                                        : null,
                                    child: const Text('Previous'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _hasMore
                                        ? () {
                                            setState(() => _currentPage++);
                                            getUsers();
                                          }
                                        : null,
                                    child: const Text('Next'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
