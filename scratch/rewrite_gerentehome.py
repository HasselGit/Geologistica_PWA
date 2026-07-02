import re

with open('lib/pages/gerentehome.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _buildKPIHighEndWeight
weight_old = """  Widget _buildKPIHighEndWeight(double kg) {
    return _GlassCard(
      accentColor: DesignTokens.secondary,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.05), shape: BoxShape.circle),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.balance_rounded, color: DesignTokens.primary, size: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: DesignTokens.secondary.withOpacity(0.2))),
                    child: Row(
                      children: [
                        const _GerentePulsingDot(),
                        const SizedBox(width: 6),
                        const Text('EN VIVO', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(kg.toStringAsFixed(0), style: const TextStyle(fontFamily: 'Manrope', fontSize: 48, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -2, fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 8),
                  Text('KG', style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.bold, color: DesignTokens.onSurfaceVariant.withOpacity(0.4))),
                ],
              ),
              const Text('CARGA TOTAL EN VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: Colors.green.shade600, size: 14),
                        const SizedBox(width: 4),
                        Text('ACTIVO', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.65,
                        child: Container(decoration: BoxDecoration(color: DesignTokens.secondary, borderRadius: BorderRadius.circular(2))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }"""

weight_new = """  Widget _buildKPIHighEndWeight(double kg) {
    return _GlassCard(
      accentColor: DesignTokens.secondary,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(width: 120, height: 120, decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.05), shape: BoxShape.circle)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.balance_rounded, color: DesignTokens.primary, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: DesignTokens.secondary.withOpacity(0.2))),
                    child: Row(
                      children: [
                        const _GerentePulsingDot(),
                        const SizedBox(width: 6),
                        const Text('EN VIVO', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(kg.toStringAsFixed(0), style: const TextStyle(fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 6),
                  Text('KG', style: TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black38)),
                ],
              ),
              const Text('CARGA TOTAL EN VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: Colors.green.shade600, size: 12),
                        const SizedBox(width: 4),
                        Text('ACTIVO', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.65,
                        child: Container(decoration: BoxDecoration(color: DesignTokens.secondary, borderRadius: BorderRadius.circular(2))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }"""

content = content.replace(weight_old, weight_new)

# 2. Update _buildKPIHighEndTrips
trips_old = """  Widget _buildKPIHighEndTrips(int enCurso, int pendientes, int terminados) {
    return _GlassCard(
      accentColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFFF59E0B), size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('EN RUTA', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green.shade700, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(enCurso.toString(), style: const TextStyle(fontFamily: 'Manrope', fontSize: 48, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -2, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            ],
          ),
          const Text('VIAJES ACTIVOS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: DesignTokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.outline.withOpacity(0.5))),
            child: Text('$enCurso moviéndose • $pendientes en espera', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54)),
          ),
        ],
      ),
    );
  }"""

trips_new = """  Widget _buildKPIHighEndTrips(int enCurso, int pendientes, int terminados) {
    return _GlassCard(
      accentColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('EN RUTA', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green.shade700, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(enCurso.toString(), style: const TextStyle(fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 6),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            ],
          ),
          const Text('VIAJES ACTIVOS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: DesignTokens.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.outline.withOpacity(0.5))),
            child: Text('$enCurso moviéndose • $pendientes en espera', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black54)),
          ),
        ],
      ),
    );
  }"""

content = content.replace(trips_old, trips_new)

# 3. Update _buildKPIHighEndStock
stock_old = """  Widget _buildKPIHighEndStock(int stock) {
    return _GlassCard(
      accentColor: Colors.red.shade400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_rounded, color: DesignTokens.primary, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ESTADO', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red.shade400, letterSpacing: 1)),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.red.shade400, size: 14),
                      const SizedBox(width: 4),
                      Text('Tambores', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(stock.toString(), style: const TextStyle(fontFamily: 'Manrope', fontSize: 48, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -2, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              Text('UNI', style: TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.onSurfaceVariant.withOpacity(0.4))),
            ],
          ),
          const Text('STOCK TAMBORES', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 24),
          SizedBox(
            height: 32,
            child: CustomPaint(painter: _GerenteSparklinePainter([5,2,8,4,9,3,7,2,6,4,8], Colors.red.shade400)),
          ),
        ],
      ),
    );
  }"""

stock_new = """  Widget _buildKPIHighEndStock(int stock) {
    return _GlassCard(
      accentColor: Colors.red.shade400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_rounded, color: DesignTokens.primary, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ESTADO', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red.shade400, letterSpacing: 1)),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.red.shade400, size: 12),
                      const SizedBox(width: 4),
                      Text('Tambores', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(stock.toString(), style: const TextStyle(fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 6),
              Text('UNI', style: TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
            ],
          ),
          const Text('STOCK TAMBORES', style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
          const SizedBox(height: 16),
          SizedBox(
            height: 24,
            child: CustomPaint(painter: _GerenteSparklinePainter([5,2,8,4,9,3,7,2,6,4,8], Colors.red.shade400)),
          ),
        ],
      ),
    );
  }"""

content = content.replace(stock_old, stock_new)

# 4. Completely replace _buildHighEndDesktopLayout
import re

desktop_old_pattern = re.compile(r"  Widget _buildHighEndDesktopLayout\(\) \{.*?\}\s*\n\s*Widget _buildKPIHighEndWeight", re.DOTALL)

desktop_new = """  Widget _buildHighEndDesktopLayout() {
    final pendCount = _viajesCount['pendientes'] ?? 0;
    final cursCount = _viajesCount['enCurso'] ?? 0;
    final termCount = _viajesCount['terminados'] ?? 0;

    return Column(
      children: [
        // FIXED HEADER + KPIs
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                        onPressed: () => context.go('/home'),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('GEOLOGÍSTICA', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
                              const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.black38),
                              Text('DASHBOARD', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.6), letterSpacing: 1)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Dashboard de Gestión', style: TextStyle(fontFamily: 'Manrope', fontSize: 32, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -1)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DesignTokens.primary.withOpacity(0.08))),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.black54),
                          onPressed: _fetchStats,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DesignTokens.primary.withOpacity(0.08))),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.black54),
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) context.go('/');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Top Row: High Impact KPIs
              Row(
                children: [
                  Expanded(flex: 5, child: _buildKPIHighEndWeight(_totalKg)),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildKPIHighEndTrips(_viajesEnCurso, pendCount, termCount)),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: _buildKPIHighEndStock(_tamboresStock)),
                ],
              ),
            ]
          )
        ),
        
        const Divider(height: 1, color: Colors.black12),
        
        // SCROLLABLE CONTENT
        Expanded(
          child: RefreshIndicator(
            color: DesignTokens.secondary,
            onRefresh: _fetchStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MATRIZ DE OPERACIONES', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
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
                  
                  // 50/50 SPLIT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: Inventario
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('INVENTARIO DE PRODUCTOS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
                                const SizedBox(width: 16),
                                Expanded(child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_productTotals.isEmpty)
                              const Center(child: Text('No hay productos gestionados aún', style: TextStyle(color: Colors.black38)))
                            else
                              ..._productTotals.map((item) {
                                final String prod = item['producto']?.toString() ?? 'DESCONOCIDO';
                                final double qty = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
                                final String unit = item['unidad']?.toString() ?? 'uni';
                                
                                IconData pIcon = Icons.inventory_2_rounded;
                                Color pColor = DesignTokens.primary;
                                bool isPrimary = false;

                                if (prod.contains('TCM')) {
                                  pIcon = Icons.hive_rounded;
                                  pColor = const Color(0xFFB45309);
                                  isPrimary = true;
                                } else if (prod.contains('TRR')) {
                                  pIcon = Icons.hive_outlined;
                                  pColor = const Color(0xFFD97706);
                                } else if (prod.contains('TAMBOR') || prod.contains('TAM')) {
                                  pIcon = Icons.adjust_rounded;
                                  pColor = const Color(0xFF0F766E);
                                } else if (prod.contains('AZUCAR') || prod.contains('AZ')) {
                                  pIcon = Icons.grain_rounded;
                                  pColor = const Color(0xFF475569);
                                }
                                
                                double percent = qty / 1000.0;
                                if (percent > 1.0) percent = 1.0;
                                if (percent < 0.05 && qty > 0) percent = 0.05;

                                return _buildProductBar(prod, 'INVENTARIO REGISTRADO', pIcon, pColor, percent, qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1), isPrimary);
                              }).toList(),
                          ]
                        )
                      ),
                      const SizedBox(width: 40),
                      
                      // RIGHT COLUMN: Viajes Activos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('DETALLE DE VIAJES ACTIVOS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
                                const SizedBox(width: 16),
                                Expanded(child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_viajesActivos.isEmpty)
                              _buildEmptyState()
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _viajesActivos.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildViajeCard(_viajesActivos[index]),
                                ),
                              ),
                          ]
                        )
                      )
                    ]
                  )
                ]
              )
            )
          )
        )
      ]
    );
  }

  Widget _buildKPIHighEndWeight"""

content = desktop_old_pattern.sub(desktop_new, content)

with open('lib/pages/gerentehome.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
