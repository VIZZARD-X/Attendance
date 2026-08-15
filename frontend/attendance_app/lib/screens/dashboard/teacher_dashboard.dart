import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'teacher_dashboard_mobile.dart';
import 'teacher_dashboard_web.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const TeacherDashboardWeb();
    }
    return const TeacherDashboardMobile();
  }
}