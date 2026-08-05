import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoggedWidget extends StatefulWidget {
  const LoggedWidget({super.key});
  
  static String routeName = 'Logged';
  static String routePath = '/logged';

  @override
  State<LoggedWidget> createState() => _LoggedWidgetState();
}

class _LoggedWidgetState extends State<LoggedWidget> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      if (mounted) context.go('/');
      return;
    }

    final role = (prefs.getString('user_puesto') ?? '').toLowerCase().trim();
    if (role.contains('chofer')) {
      if (mounted) context.go('/choferHome');
    } else if (role.contains('gerente') || role.contains('ceo') || role.contains('operaciones') || role.contains('director') || role.contains('admin')) {
      if (mounted) context.go('/gerenteHome');
    } else if (role.contains('deposito')) {
      if (mounted) context.go('/depositoHome');
    } else if (role.contains('compras')) {
      if (mounted) context.go('/comprasHome');
    } else {
      if (mounted) context.go('/gerenteHome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDBE49)),
        ),
      ),
    );
  }
}
