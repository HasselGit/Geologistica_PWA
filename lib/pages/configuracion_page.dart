import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/design_tokens.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _empresaController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  
  bool _notificacionesActivas = true;
  bool _modoOscuro = false;
  String _idiomaSeleccionado = 'Español';
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _empresaController.text = prefs.getString('conf_empresa') ?? 'GeoLogística S.A.';
      _direccionController.text = prefs.getString('conf_direccion') ?? 'Av. Principal 123';
      _telefonoController.text = prefs.getString('conf_telefono') ?? '+54 11 1234-5678';
      _notificacionesActivas = prefs.getBool('conf_notificaciones') ?? true;
      _modoOscuro = prefs.getBool('conf_modo_oscuro') ?? false;
      _idiomaSeleccionado = prefs.getString('conf_idioma') ?? 'Español';
    } catch (e) {
      _empresaController.text = 'GeoLogística S.A.';
      _direccionController.text = 'Av. Principal 123';
      _telefonoController.text = '+54 11 1234-5678';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('conf_empresa', _empresaController.text);
      await prefs.setString('conf_direccion', _direccionController.text);
      await prefs.setString('conf_telefono', _telefonoController.text);
      await prefs.setBool('conf_notificaciones', _notificacionesActivas);
      await prefs.setBool('conf_modo_oscuro', _modoOscuro);
      await prefs.setString('conf_idioma', _idiomaSeleccionado);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configuración guardada', style: DesignTokens.bodyStyle(color: DesignTokens.surface)),
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
        _saveSettings();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _loadSettings();
      }
    }
  }

  @override
  void dispose() {
    _empresaController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
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
            'Configuración del Sistema',
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
          child: _buildSidebarMenu(),
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
        _buildSidebarMenu(),
        const SizedBox(height: 24),
        _buildMainContent(),
      ],
    );
  }

  Widget _buildSidebarMenu() {
    return Container(
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
        children: [
          _buildMenuItem(Icons.business, 'Empresa', true),
          _buildMenuItem(Icons.notifications, 'Notificaciones', false),
          _buildMenuItem(Icons.language, 'Idioma y Región', false),
          _buildMenuItem(Icons.security, 'Seguridad', false),
          _buildMenuItem(Icons.color_lens, 'Apariencia', false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? DesignTokens.surfaceLow : Colors.transparent,
        border: isSelected ? const Border(left: BorderSide(color: DesignTokens.secondary, width: 4)) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? DesignTokens.secondary : DesignTokens.onSurfaceVariant),
        title: Text(
          title,
          style: DesignTokens.bodyStyle().copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? DesignTokens.onSurface : DesignTokens.onSurfaceVariant,
          ),
        ),
        onTap: () {
          // TODO: Implement menu navigation
        },
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
            Text('Datos de la Empresa', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _empresaController,
              label: 'Nombre de la Empresa',
              icon: Icons.business,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _direccionController,
              label: 'Dirección',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _telefonoController,
              label: 'Teléfono',
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: 40),
            
            Text('Preferencias', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text('Notificaciones Activas', style: DesignTokens.bodyStyle()),
              subtitle: Text('Recibir alertas del sistema', style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant)),
              value: _notificacionesActivas,
              activeColor: DesignTokens.secondary,
              onChanged: (val) => setState(() => _notificacionesActivas = val),
            ),
            SwitchListTile(
              title: Text('Modo Oscuro', style: DesignTokens.bodyStyle()),
              subtitle: Text('Cambiar tema de la aplicación', style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant)),
              value: _modoOscuro,
              activeColor: DesignTokens.secondary,
              onChanged: (val) => setState(() => _modoOscuro = val),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Idioma', style: DesignTokens.bodyStyle()),
              trailing: DropdownButton<String>(
                value: _idiomaSeleccionado,
                underline: const SizedBox(),
                items: ['Español', 'Inglés', 'Portugués'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: DesignTokens.bodyStyle()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _idiomaSeleccionado = val);
                },
              ),
            ),
            
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loadSettings,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: Text('Cancelar (Esc)', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveSettings,
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
  }) {
    return TextFormField(
      controller: controller,
      style: DesignTokens.bodyStyle(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
        prefixIcon: Icon(icon, color: DesignTokens.onSurfaceVariant),
        filled: true,
        fillColor: DesignTokens.surface,
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
