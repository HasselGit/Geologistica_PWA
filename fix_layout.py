import re

with open('lib/pages/gerentehome.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the layout
old_layout = '''    return RefreshIndicator(
      color: DesignTokens.secondary,
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ['''

new_layout = '''    return RefreshIndicator(
      color: DesignTokens.secondary,
      onRefresh: _fetchStats,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ['''

content = content.replace(old_layout, new_layout)

# Matrix section replacement
matrix_old = '''            const SizedBox(height: 40),

            // Status Matrix
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MATRIZ DE OPERACIONES', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.4), letterSpacing: 2)),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.primary.withOpacity(0.08))), child: const Icon(Icons.filter_list_rounded, size: 16, color: Colors.black54)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.primary.withOpacity(0.08))), child: const Icon(Icons.download_rounded, size: 16, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildMatrixRow(
              'Recolecciones', 'MIEL TCM/TRR', Icons.download_rounded, Colors.blue.shade700, Colors.blue.shade700.withOpacity(0.1),
              [
                _solicitudesCount['recoleccionesByState']?['Pendiente'] ?? 0,
                _solicitudesCount['recoleccionesByState']?['Asignada'] ?? 0,
                _solicitudesCount['recoleccionesByState']?['En Curso'] ?? 0,
                _solicitudesCount['recoleccionesByState']?['Terminada'] ?? 0,
              ],
              () {
                context.go('/recolecciones');
                _fetchStats();
              }
            ),
            _buildMatrixRow(
              'Distribuciones', 'INSUMOS/AZÚCAR', Icons.upload_rounded, Colors.green.shade600, Colors.green.shade600.withOpacity(0.1),
              [
                _solicitudesCount['distribucionesByState']?['Pendiente'] ?? 0,
                _solicitudesCount['distribucionesByState']?['Asignada'] ?? 0,
                _solicitudesCount['distribucionesByState']?['En Curso'] ?? 0,
                _solicitudesCount['distribucionesByState']?['Terminada'] ?? 0,
              ],
              () {
                context.go('/distribuciones');
                _fetchStats();
              }
            ),
            
            const SizedBox(height: 40),

            // Product Inventory'''

matrix_new = '''                ],
              ),
            ),
          ),

          // Status Matrix - Pinned
          SliverPersistentHeader(
            pinned: true,
            delegate: _MatrixHeaderDelegate(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MATRIZ DE OPERACIONES', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.4), letterSpacing: 2)),
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.primary.withOpacity(0.08))), child: const Icon(Icons.filter_list_rounded, size: 16, color: Colors.black54)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.primary.withOpacity(0.08))), child: const Icon(Icons.download_rounded, size: 16, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMatrixRow(
                    'Recolecciones', 'MIEL TCM/TRR', Icons.download_rounded, Colors.blue.shade700, Colors.blue.shade700.withOpacity(0.1),
                    [
                      _solicitudesCount['recoleccionesByState']?['Pendiente'] ?? 0,
                      _solicitudesCount['recoleccionesByState']?['Asignada'] ?? 0,
                      _solicitudesCount['recoleccionesByState']?['En Curso'] ?? 0,
                      _solicitudesCount['recoleccionesByState']?['Terminada'] ?? 0,
                    ],
                    () {
                      context.go('/recolecciones');
                      _fetchStats();
                    }
                  ),
                  _buildMatrixRow(
                    'Distribuciones', 'INSUMOS/AZÚCAR', Icons.upload_rounded, Colors.green.shade600, Colors.green.shade600.withOpacity(0.1),
                    [
                      _solicitudesCount['distribucionesByState']?['Pendiente'] ?? 0,
                      _solicitudesCount['distribucionesByState']?['Asignada'] ?? 0,
                      _solicitudesCount['distribucionesByState']?['En Curso'] ?? 0,
                      _solicitudesCount['distribucionesByState']?['Terminada'] ?? 0,
                    ],
                    () {
                      context.go('/distribuciones');
                      _fetchStats();
                    }
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Product Inventory'''

content = content.replace(matrix_old, matrix_new)

# End of CustomScrollView
end_old = '''              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIHighEndWeight'''

end_new = '''              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIHighEndWeight'''

content = content.replace(end_old, end_new)

with open('lib/pages/gerentehome.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Layout updated successfully.")
