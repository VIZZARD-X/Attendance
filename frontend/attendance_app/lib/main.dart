import 'dart:convert';
import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard/student_dashboard.dart';
import 'screens/dashboard/teacher_dashboard.dart';
import 'screens/teacher/session_create_screen.dart';
import 'screens/teacher/my_classes_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  String initialRoute = '/login';
  
  // Extract initial path from the web URL if present
  final currentPath = Uri.base.fragment;
  if (currentPath.startsWith('/join/')) {
    final code = currentPath.split('/join/').last;
    await StorageService.write(key: 'pending_join_code', value: code);
  }

  final userJson = await StorageService.read(key: 'user');
  if (userJson != null && userJson.isNotEmpty) {
    try {
      final user = jsonDecode(userJson);
      if (user['role'] == 'student') {
        initialRoute = '/student';
      } else if (user['role'] == 'teacher') {
        initialRoute = '/teacher';
      } else if (user['role'] == 'admin') {
        initialRoute = '/admin';
      }
    } catch (e) {
      debugPrint('Error parsing saved user: $e');
    }
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/student': (context) => const StudentDashboardPage(),
        '/teacher': (context) => const TeacherDashboardPage(),
        '/teacher/my-classes': (context) => const MyClassesScreen(),
        '/admin': (context) => const AdminDashboardPage(),
        '/teacher/create-session': (context) => const SessionPage(
            // Add required subjects parameter later use backend (for testing)
          subjects: [
            {'code': 'CS101', 'name': 'Computer Science'},
            {'code': 'MA102', 'name': 'Mathematics'},
            {'code': 'PH103', 'name': 'Physics'},
            {'code': 'EN104', 'name': 'English'},
            {'code': 'CH105', 'name': 'Chemistry'},
            {'code': 'BIO106', 'name': 'Biology'},
          ],
        ),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/join/')) {
          final code = settings.name!.split('/join/').last;
          // Save for when they log in
          StorageService.write(key: 'pending_join_code', value: code);
          // Redirect based on role
          return MaterialPageRoute(
            builder: (_) => initialRoute == '/student' 
                ? const StudentDashboardPage() 
                : const LoginPage(),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }
}