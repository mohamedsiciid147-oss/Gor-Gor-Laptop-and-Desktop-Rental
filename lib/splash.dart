import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'pages/login_page.dart';

class Splash extends StatefulWidget {
  static const String id = 'splash';
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  gotToLogin() async {
    Timer.periodic(Duration(seconds: 3), (d) {
      Navigator.pushReplacementNamed(context, LoginPage.id);
    });
  }

  @override
  void initState() {
    gotToLogin();
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: Shimmer.fromColors(
                baseColor: Theme.of(context).primaryColor,
                highlightColor: Colors.white,
                child: Image.asset('images/logo.png'),
              ),
            ),
            Text(
              "GORGOR LAPTOP AND DESKTOP RENTAL",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
