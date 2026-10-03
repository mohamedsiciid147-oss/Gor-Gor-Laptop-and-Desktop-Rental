import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'pages/admin/admin_home.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/website_page.dart';
import 'splash.dart';

Future<void> main() async {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: EasyLoading.init(),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff6f9ff),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff155eef),
          primary: const Color(0xff155eef),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xff0b1b45),
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfff7f9fd),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffdfe7f5)),
          ),
        ),
      ),
      routes: {
        Splash.id: (context) => Splash(),
        HomePage.id: (context) => HomePage(),
        LoginPage.id: (context) => LoginPage(),
        WebsitePage.id: (context) => const WebsitePage(),
        AdminHome.id: (context) => AdminHome(),
      },
      initialRoute: WebsitePage.id,
    );
  }
}
