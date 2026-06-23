import '../backend/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ComprasHomeWidget extends StatefulWidget {
  const ComprasHomeWidget({super.key});

  @override
  State<ComprasHomeWidget> createState() => _ComprasHomeWidgetState();
}

class _ComprasHomeWidgetState extends State<ComprasHomeWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: DesignTokens.surfaceLow,
        appBar: AppBar(
          backgroundColor: DesignTokens.surface,
          automaticallyImplyLeading: false,
          toolbarHeight: 70,
          elevation: 0,
          title: Text(
            'Panel de Compras',
            style: DesignTokens.headlineStyle().copyWith(fontSize: 20),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, color: DesignTokens.primary),
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/');
                },
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de Adquisiciones',
                  style: DesignTokens.headlineStyle().copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Control central de miel y suministros apícolas.',
                  style: TextStyle(color: DesignTokens.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DesignTokens.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_cart_rounded, size: 40, color: DesignTokens.secondary),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Gestión de Necesidades',
                        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Administre las solicitudes de recolección y distribución pendientes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DesignTokens.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => context.push('/necesidades'),
                          style: DesignTokens.secondaryButtonStyle,
                          child: const Text('GESTIONAR NECESIDADES'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
