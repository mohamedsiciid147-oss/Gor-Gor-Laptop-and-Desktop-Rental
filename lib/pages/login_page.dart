import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import 'admin/admin_home.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  static const String id = 'login-page';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  bool isLogin = true;
  bool _routeOptionsApplied = false;
  bool obscurePassword = true;
  bool _isSubmitting = false;
  String selectedAccountType = 'Student';
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  bool _isInstitutionalEmail(String value) {
    return RegExp(r'^[^\s@]+@(?:[^\s@]+\.)?(?:edu|ac)(?:\.[a-z]{2,})?$', caseSensitive: false)
        .hasMatch(value);
  }

  bool _isSixDigitPassword(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value);
  }

  Future<void> check() async {
    var prefs = await SharedPreferences.getInstance();
    var loggedIn = prefs.getString('loggedIn');
    final userDataString = prefs.getString('userData');
    if (loggedIn != 'true' || userDataString == null) {
      return;
    }

    try {
      final userData = jsonDecode(userDataString);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        userData['role'] == 'admin' ? AdminHome.id : HomePage.id,
      );
    } catch (_) {
      await prefs.remove('loggedIn');
      await prefs.remove('userData');
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    setState(() {
      _emailError = email.isEmpty
          ? 'Email address is required.'
          : !_isValidEmail(email)
          ? 'Enter a valid email address.'
          : null;
      _passwordError = password.isEmpty
          ? 'Password is required.'
          : !_isSixDigitPassword(password)
          ? 'Password must be exactly 6 digits.'
          : null;
      _formError = null;
    });

    if (_emailError != null || _passwordError != null) return;

    try {
      setState(() => _isSubmitting = true);
      List users = await Db.get(
        'users',
        filters: {
          'email': email,
          'password': password,
        },
      );
      if (users.isEmpty) {
        if (mounted) {
          setState(() => _formError = 'Incorrect email or password.');
        }
        return;
      }
      if (users.isNotEmpty && users[0] != null) {
        var prefs = await SharedPreferences.getInstance();
        prefs.setString('loggedIn', 'true');
        prefs.setString('userData', jsonEncode(users[0]));
        if (users[0]['role'] != 'admin') {
          Navigator.pushReplacementNamed(context, HomePage.id);
        } else {
          Navigator.pushReplacementNamed(context, AdminHome.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'We could not sign you in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> signup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    final isStudent = selectedAccountType == 'Student';

    setState(() {
      _nameError = name.isEmpty ? 'Full name is required.' : null;
      _emailError = email.isEmpty
          ? 'Email address is required.'
          : !_isValidEmail(email)
          ? 'Enter a valid email address.'
          : isStudent && !_isInstitutionalEmail(email)
          ? 'Students must use an institutional email address.'
          : null;
      _passwordError = password.isEmpty
          ? 'Password is required.'
          : !_isSixDigitPassword(password)
          ? 'Password must be exactly 6 digits.'
          : null;
      _formError = null;
    });

    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      List users = await Db.get(
        'users',
        filters: {
          'email': email,
        },
      );
      if (users.isNotEmpty) {
        if (mounted) {
          setState(() => _emailError = 'An account with this email already exists.');
        }
      } else {
        final res = await Db.post('users', {
          'name': name,
          'email': email,
          'password': password,
          'mobile': mobileController.text.trim(),
          'role': isStudent ? 'student' : 'customer',
        });
        final created = res is List && res.isNotEmpty ? res.first : null;
        if (created != null) {
          var prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedIn', 'true');
          await prefs.setString('userData', jsonEncode(created));
          if (mounted) Navigator.pushReplacementNamed(context, HomePage.id);
        }
      }
      if (mounted && users.isEmpty) {
        nameController.clear();
        emailController.clear();
        passwordController.clear();
        mobileController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'We could not create your account. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _switchAuthMode() {
    setState(() {
      isLogin = !isLogin;
      nameController.clear();
      emailController.clear();
      passwordController.clear();
      mobileController.clear();
      selectedAccountType = 'Student';
      obscurePassword = true;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _formError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    check();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeOptionsApplied) return;
    _routeOptionsApplied = true;
    final options = ModalRoute.of(context)?.settings.arguments as LoginOptions?;
    if (options != null) {
      isLogin = !options.register;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffdceaff),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 900;

          if (isSmallScreen) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildLeftSide(isSmallScreen: true),
                  _buildRightSide(isSmallScreen: true),
                ],
              ),
            );
          } else {
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320, minHeight: 700),
                  child: Container(
                    margin: const EdgeInsets.all(28),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x330b1b45),
                          blurRadius: 34,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: _buildLeftSide(isSmallScreen: false)),
                        Expanded(flex: 4, child: _buildRightSide(isSmallScreen: false)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Responsive Left Side / Top Banner Section
  Widget _buildLeftSide({required bool isSmallScreen}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isSmallScreen
            ? const BorderRadius.only(bottomRight: Radius.circular(70))
            : const BorderRadius.only(bottomRight: Radius.circular(220)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160,
            left: -130,
            child: Container(
              height: 330,
              width: 330,
              decoration: const BoxDecoration(
                color: Color(0xffe6f4ff),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 30 : 60,
              vertical: isSmallScreen ? 28 : 18,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: isSmallScreen ? 104 : 148,
                  width: isSmallScreen ? 104 : 148,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x15004fc4),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('images/gorgor_logo.jpeg', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'GOR GOR\nTECH RENTAL',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 31 : 42,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xff0b1b45),
                    height: 1.06,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kiro fudud oo laptops iyo desktops tayo leh.',
                  style: TextStyle(
                    color: const Color(0xff52627e),
                    fontSize: isSmallScreen ? 15 : 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildFeatureBadge(Icons.verified_outlined, 'Quality checked'),
                    _buildFeatureBadge(Icons.calendar_month_outlined, 'Flexible rental'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Responsive Right Side / Login Card Section
  Widget _buildRightSide({required bool isSmallScreen}) {
    return Container(
      color: const Color(0xff003ebd),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isSmallScreen ? 440 : 430),
          padding: EdgeInsets.all(isSmallScreen ? 24 : 28),
          margin: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 20 : 24,
            vertical: isSmallScreen ? 28 : 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  isLogin ? "Welcome Back" : "Create Account",
                  style: const TextStyle(
                    color: Color(0xff0b1b45),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  isLogin ? "Sign in to manage your rental." : "Create your Gor Gor account.",
                  style: const TextStyle(
                    color: Color(0xff6b7890),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!isLogin) ...[
                _buildTextField(
                  controller: nameController,
                  hintText: "Full Name",
                  icon: Icons.person_outline,
                  errorText: _nameError,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAccountType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: "Select account type",
                    hintStyle: const TextStyle(color: Color(0xff71809a)),
                    prefixIcon: const Icon(
                      Icons.people_alt_outlined,
                      color: Color(0xff155eef),
                    ),
                    filled: true,
                    fillColor: const Color(0xfff2f8ff),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffcfe0f8)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Customer', child: Text('Customer')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedAccountType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: mobileController,
                  hintText: "Mobile Number",
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: 16),
              ],
              _buildTextField(
                controller: emailController,
                hintText: "Email Address",
                icon: Icons.email_outlined,
                errorText: _emailError,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Color(0xff0b1b45)),
                decoration: InputDecoration(
                  hintText: "6-digit password",
                  counterText: '',
                  hintStyle: const TextStyle(color: Color(0xff71809a)),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Color(0xff155eef),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xff52627e),
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xfff2f8ff),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffcfe0f8)),
                  ),
                  errorText: _passwordError,
                  errorStyle: const TextStyle(fontSize: 12),
                ),
              ),
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 8),
              if (_formError != null) ...[
                const SizedBox(height: 8),
                _buildFormError(_formError!),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () {
                    if (isLogin) {
                      login();
                    } else {
                      signup();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0068e8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isLogin ? "LOGIN" : "CREATE ACCOUNT",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting ? null : _switchAuthMode,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Color(0xff6b7890)),
                      children: [
                        TextSpan(
                          text: isLogin
                              ? "New to GOR GOR? "
                              : "Already have an account? ",
                        ),
                        TextSpan(
                          text: isLogin ? "Create an account" : "Sign in",
                          style: TextStyle(
                            color: Color(0xff155eef),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '© 2026 GOR GOR Tech Rental',
                  style: TextStyle(color: Color(0xff71809a), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget for the left side item feature badges
  Widget _buildFeatureBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffedf6ff),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffc8e5ff)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xff155eef), size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Color(0xff31527b))),
        ],
      ),
    );
  }

  Widget _buildFormError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffffeef1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffffc7d1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xffd92d20), size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xffb42318), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot your password?'),
        content: const Text(
          'Please contact the GOR GOR support team and they will help you reset your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Helper input field widget to modularize text inputs clean code structure
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xff0b1b45)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xff71809a)),
        prefixIcon: Icon(icon, color: const Color(0xff155eef)),
        filled: true,
        fillColor: const Color(0xfff2f8ff),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffcfe0f8)),
        ),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class LoginOptions {
  final bool register;
  // Kept for hot-reload compatibility with sessions started before the
  // admin selector was removed. It is no longer used by the login screen.
  final bool admin;
  const LoginOptions({this.register = false, this.admin = false});
}
