import re

with open('lib/pages/carga_detalle.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix _buildDetalleDesktop
content = content.replace(
    'padding: const EdgeInsets.fromLTRB(120, 48, 40, 64),',
    'padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),\n              child: Padding(\n                padding: const EdgeInsets.only(top: 48, bottom: 64),'
)

# Fix _buildNewCargaDesktop which still has the split columns
old_new_carga = '''  Widget _buildNewCargaDesktop() {
    if (_isChofer) return _buildNewCarga();

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeoSidebar(userRole: _userRole ?? '', userEmail: _userEmail ?? '', displayName: _userEmail ?? ''),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,'''
                
new_new_carga = '''  Widget _buildNewCargaDesktop() {
    if (_isChofer) return _buildNewCarga();

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeoSidebar(userRole: _userRole ?? '', userEmail: _userEmail ?? '', displayName: _userEmail ?? ''),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
              child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 64),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,'''

content = content.replace(old_new_carga, new_new_carga)

# Now fix the right column of _buildNewCargaDesktop which also has Expanded(flex: 6)
old_new_carga_right = '''          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 40, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  _labelText('ÍTEMS DE LA CARGA'),
                  const SizedBox(height: 10),'''

new_new_carga_right = '''                    const SizedBox(width: 48),
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: DesignTokens.primary.withOpacity(0.04)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelText('ÍTEMS DE LA CARGA'),
                            const SizedBox(height: 24),'''

content = content.replace(old_new_carga_right, new_new_carga_right)

# Wait, there are closing braces missing if I change the hierarchy.
# Original:
#   ] ) ) ), Expanded(6, SingleChildScrollView( ... ] ) ) ) ] ) ); }
# New:
#   ] ) ) , SizedBox, Expanded(6, Container( ... ] ) ) ) ] ) ) ) ) ] ) ); }
# This is tricky with simple string replace. Let's use regex to find the end of the left column.
