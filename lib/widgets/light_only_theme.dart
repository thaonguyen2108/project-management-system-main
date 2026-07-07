import 'package:flutter/material.dart';
import 'package:todo/core/app_style.dart';

class LightOnlyTheme extends StatelessWidget {
  final Widget child;

  const LightOnlyTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(data: AppTheme.light, child: child);
  }
}
