import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/design_tokens.dart';

class PerfilUsuarioPage extends StatefulWidget {
  const PerfilUsuarioPage({super.key});

  @override
  State<PerfilUsuarioPage> createState() => _PerfilUsuarioPageState();
}

class _PerfilUsuarioPageState extends State<PerfilUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _rolController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _nombreController.text = prefs.getString('user_name') ?? 'Usuario de Prueba';
      _emailController.text = prefs.getString('user_email') ?? 'usuario@geologistica.com';
      _rolController.text = prefs.getString('user_role') ?? 'Administrador';
    } catch (e) {
      // Fallback a placeholders
      _nombreController.text = 'Usuario de Prueba';
      _emailController.text = 'usuario@geologistica.com';
      _rolController.text = 'Administrador';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nombreController.text);
      await prefs.setString('user_email', _emailController.text);
      await prefs.setString('user_role', _rolController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perfil guardado exitosamente', style: DesignTokens.bodyStyle(color: DesignTokens.surface)),
            backgroundColor: DesignTokens.primaryVariant,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar', style: DesignTokens.bodyStyle(color: DesignTokens.surface)),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.enter) {
        _saveUserData();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _loadUserData(); // Cancel and reload
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _rolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: DesignTokens.surfaceLow,
        appBar: AppBar(
          backgroundColor: DesignTokens.surface,
          elevation: 0,
          title: Text(
            'Perfil de Usuario',
            style: DesignTokens.headlineStyle(),
          ),
          iconTheme: const IconThemeData(color: DesignTokens.onSurface),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = constraints.maxWidth > 900;
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: isWeb ? _buildWebLayout() : _buildMobileLayout(),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildSidebar(),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 7,
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSidebar(),
        const SizedBox(height: 24),
        _buildMainContent(),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: DesignTokens.primaryVariant,
            child: Icon(Icons.person, size: 50, color: DesignTokens.surface),
          ),
          const SizedBox(height: 16),
          Text(
            _nombreController.text.isNotEmpty ? _nombreController.text : 'Usuario',
            style: DesignTokens.headlineStyle(color: DesignTokens.onSurface).copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _rolController.text.isNotEmpty ? _rolController.text : 'Rol',
            style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          const Divider(color: DesignTokens.outline),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: DesignTokens.secondary),
            title: Text('Cambiar foto', style: DesignTokens.bodyStyle()),
            onTap: () {
              // TODO: Implement image picker
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información Personal',
              style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _nombreController,
              label: 'Nombre Completo',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _emailController,
              label: 'Correo Electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _rolController,
              label: 'Rol (Solo lectura)',
              icon: Icons.badge_outlined,
              readOnly: true,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loadUserData,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: Text('Cancelar (Esc)', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveUserData,
                  style: DesignTokens.primaryButtonStyle,
                  child: const Text('Guardar (Ctrl+Enter)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: DesignTokens.bodyStyle(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
        prefixIcon: Icon(icon, color: DesignTokens.onSurfaceVariant),
        filled: true,
        fillColor: readOnly ? DesignTokens.surfaceLow : DesignTokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.secondary, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es requerido';
        }
        return null;
      },
    );
  }
}
