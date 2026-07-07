import "package:flutter/material.dart";
import "package:todo/core/navigation.dart";
import "package:todo/widgets/ui.dart";
import 'dart:async';
import 'package:todo/core/network_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  bool isOnline = false;

  // @override
  // void initState() {
  //   super.initState();
  //   _checkInitialNetwork();
  // }
  // Future<void> _checkInitialNetwork() async {
  //   await Future.delayed(const Duration(seconds: 2));

  //   if (!mounted) return;
  //   await hasInternet(context);
  // }


  @override
  void initState() {
    super.initState();
    _checkInitialNetwork();
  }

  Future<void> _checkInitialNetwork() async {
    await Future.delayed(const Duration(seconds: 2));

    final result = await hasInternet();

    if (!mounted) return;

    setState(() {
      isOnline = result;
    });

    if (!result) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoInternetDialog();
      });
    } else {
      AppNav.goToAuthGate(context);
    }
  }

  void _showNoInternetDialog() {
    dialog( 
      context, 
      title: "Lỗi kết nối", 
      message: "Vui lòng kiểm tra kết nối internet trước khi nhấm 'Kiểm tra lại'", 
      okText: "Kiểm tra lại", onOk: () { _checkInitialNetwork(); }, 
    );
  }

  @override 
  Widget build(BuildContext context) {
    return screen(
      safeArea: false,

      body: stack(
        children: [

          image(
            "assets/images/hinh_nen_1.jpg",
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ), // image

          align(
            alignment: Alignment.center,

            child: column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                image(
                  "assets/images/logo.png",
                  width: MediaQuery.of(context).size.width / 3.2,
                  height: MediaQuery.of(context).size.width / 3.2,
                  radius: BorderRadius.circular(12)
                ),

                box(height: 10),

                text(
                  "Simply made for you",
                  align: TextAlign.center,
                  weight: FontWeight.bold,
                  size: 20,
                  color: Colors.white,
                ),

                text(
                  "Work smarter - Live better",
                  align: TextAlign.center,
                  weight: FontWeight.w500,
                  size: 14,
                  color: const Color.fromARGB(255, 137, 168, 191),
                )

              ],
            )
          )

        ],
      ), // stack
      
    ); // screen
  }
}