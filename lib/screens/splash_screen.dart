import 'package:flutter/material.dart';
import '../services/ahram_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final service = await AhramService.create();
    final hasSession = await service.hasSavedSession();
    
    if (!mounted) return;
    
    if (hasSession) {
      try {
        final issues = await service.fetchIssues(['2810']);
        if (issues.isNotEmpty) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(service: service)));
          return;
        }
      } catch (_) {}
    }
    
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(service: service)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
    );
  }
}
