import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../backend/supabase_service.dart';
import '../backend/productos_data.dart';
import '../backend/design_tokens.dart';
import '../backend/app_states.dart';
import '../widgets/geo_sidebar.dart';

class NecesidadesPageWidget extends StatefulWidget {
  const NecesidadesPageWidget({super.key});

  @override
  State<NecesidadesPageWidget> createState() => _NecesidadesPageWidgetState();
}

class _NecesidadesPageWidgetState extends State<NecesidadesPageWidget> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _necesidades = [];
  List<Map<String, dynamic>> _apicultores = [];
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _filteredNecesidades = [];
  Map<String, String> _solicitudToViaje = {};
  bool _loading = true;
  bool _isCardView = true;
  String? _error;
  String? _userRole;
  String? _userEmail;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
    _searchController.addListener(_filterNecesidades);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('userRole');
      final userEmail = prefs.getString('userEmail');
      final service = SupabaseService();
      final neceData = await service.getAllNecesidades();
      final apiData = await service.getApicultores();
      final prodData = await service.getProductos();

      // Consultar relación de solicitud_id a viaje_id desde la tabla paradas
      final List<dynamic> paradasRaw = await Supabase.instance.client
          .from('paradas')
          .select('solicitud_id, viaje_id')
          .not('solicitud_id', 'is', null);

      final Map<String, String> solToViaje = {};
      for (var p in paradasRaw) {
        if (p['solicitud_id'] != null && p['viaje_id'] != null) {
          solToViaje[p['solicitud_id'].toString()] = p['viaje_id'].toString();
        }
      }

      if (mounted) {
        setState(() {
          _userRole = userRole;
          _userEmail = userEmail;
          _necesidades = neceData;
          _filteredNecesidades = neceData;
          _apicultores = apiData;
          _productos = List<Map<String, dynamic>>.from(prodData);
          _solicitudToViaje = solToViaje;
          _loading = false;
        });
      }
    } catch (e) {
      print('NecesidadesPage: Error en _fetchData: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filterNecesidades() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNecesidades = _necesidades.where((n) {
        final apicultor = (n['apicultores']?['nombre'] ?? '').toString().toLowerCase();
        final localidad = (n['localidad'] ?? n['apicultores']?['localidad'] ?? '').toString().toLowerCase();
        final producto = (n['producto'] ?? '').toString().toLowerCase();
        final codigo = (n['solicitud_codigo'] ?? '').toString().toLowerCase();
        
        return apicultor.contains(query) || 
               localidad.contains(query) || 
               producto.contains(query) ||
               codigo.contains(query);
      }).toList();
    });
  }

  Future<void> _addNecesidad() async {
    await _showSolicitudModal();
  }

  Future<void> _editNecesidad(Map<String, dynamic> data) async {
    await _showSolicitudModal(data: data);
  }

  Future<void> _showSolicitudModal({Map<String, dynamic>? data}) async {
    final bool isEdit = data != null;
    Map<String, dynamic>? selectedApicultor;
    if (isEdit) {
      selectedApicultor = _apicultores.firstWhere(
        (a) => (a['apicultor_codigo'] ?? a['id']) == data['apicultor_id'],
        orElse: () => {'nombre': 'Apicultor ${data['apicultor_id']}', 'localidad': data['localidad'], 'id': data['apicultor_id']}
      );
    }
    
    String? selectedProducto = data?['producto'];
    final cantidadController = TextEditingController(text: data?['cantidad']?.toString() ?? '');
    String selectedTipo = data?['tipo'] ?? (_tabController.index == 0 ? 'Recolección' : 'Distribución');

    final List<Map<String, dynamic>> productos = _productos.isNotEmpty ? _productos : ProductosData.masterCatalog;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBF9F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'Editar Solicitud' : 'Nueva Solicitud', 
                    style: const TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 20),
              
              // Apicultor Searchable Selector
              const Text('Apicultor', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (context) {
                      String searchQuery = '';
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          final filteredApis = _apicultores.where((a) {
                            final name = a['nombre'].toString().toLowerCase();
                            final loc = (a['localidad'] ?? '').toString().toLowerCase();
                            final code = (a['apicultor_codigo'] ?? '').toString().toLowerCase();
                            final query = searchQuery.toLowerCase();
                            return name.contains(query) || loc.contains(query) || code.contains(query);
                          }).toList();
                          return AlertDialog(
                            title: const Text('Buscar Apicultor'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(hintText: 'Nombre...', prefixIcon: Icon(Icons.search)),
                                    onChanged: (v) => setDialogState(() => searchQuery = v),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredApis.length,
                                      itemBuilder: (context, i) {
                                        final api = filteredApis[i];
                                        final codigo = api['apicultor_codigo'] ?? api['id']?.toString().substring(0,6).toUpperCase();
                                        return ListTile(
                                          title: Text(api['nombre']),
                                          subtitle: Text('${api['localidad'] ?? ''} • Cod: $codigo'),
                                          onTap: () => Navigator.pop(context, api),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                  if (result != null) {
                    setModalState(() {
                      selectedApicultor = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                  ),
                    child: Row(
                      children: [
                        Icon(Icons.person_search_rounded, size: 20, color: const Color(0xFF08201A).withOpacity(0.5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedApicultor != null 
                              ? '${selectedApicultor!['nombre']} (${selectedApicultor!['apicultor_codigo'] ?? ''})' 
                              : 'Seleccionar apicultor...', 
                            style: TextStyle(
                              color: selectedApicultor != null ? const Color(0xFF08201A) : Colors.black38,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Localidad (Auto)
              if (selectedApicultor != null) ...[
                const Text('Localidad Detectada', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF08201A).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    selectedApicultor!['localidad'] ?? 'Sin localidad',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tipo', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedTipo,
                              items: ['Recolección', 'Distribución'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setModalState(() => selectedTipo = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cantidad', 
                          style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: cantidadController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            hintText: 'Ej: 10',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Producto Searchable Selector
              const Text('Producto', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      String searchQuery = '';
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          final filteredProds = productos.where((p) {
                            final code = (p['codigo'] ?? p['producto'] ?? '').toString().toLowerCase();
                            final desc = (p['descripcion'] ?? '').toString().toLowerCase();
                            final q = searchQuery.toLowerCase();
                            return code.contains(q) || desc.contains(q);
                          }).toList();
                          return AlertDialog(
                            title: const Text('Buscar Producto'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(hintText: 'Nombre del producto...', prefixIcon: Icon(Icons.inventory_2_rounded)),
                                    onChanged: (v) => setDialogState(() => searchQuery = v),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredProds.length,
                                      itemBuilder: (context, i) => ListTile(
                                        title: Text((filteredProds[i]['codigo'] ?? filteredProds[i]['producto'] ?? '').toString()),
                                        subtitle: Text(filteredProds[i]['descripcion'] ?? ''),
                                        trailing: Text(filteredProds[i]['unidad'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        onTap: () => Navigator.pop(context, filteredProds[i]['codigo'] ?? filteredProds[i]['producto']),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                  if (result != null) {
                    setModalState(() {
                      selectedProducto = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: const Color(0xFF08201A).withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Text(selectedProducto ?? 'Seleccionar producto...', 
                        style: TextStyle(color: selectedProducto != null ? const Color(0xFF08201A) : Colors.black38)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedApicultor == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un apicultor')));
                      return;
                    }
                    if (cantidadController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa una cantidad estimada')));
                      return;
                    }
                    if (selectedProducto == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un producto')));
                      return;
                    }

                    try {
                      final payload = {
                        'apicultor_id': selectedApicultor!['apicultor_codigo'] ?? selectedApicultor!['id'],
                        'producto': selectedProducto,
                        'cantidad': double.tryParse(cantidadController.text) ?? 0,
                        'tipo': selectedTipo,
                        'localidad': selectedApicultor!['localidad'],
                        'estado': data?['estado'] ?? AppStates.pendiente,
                      };

                      if (isEdit) {
                        await SupabaseService().updateSolicitud(data!['id'].toString(), payload);
                      } else {
                        payload['solicitud_codigo'] = 'SOL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                        await SupabaseService().createNecesidad(payload);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit ? 'Solicitud actualizada' : 'Solicitud guardada'), 
                          backgroundColor: Colors.green
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: DesignTokens.primaryButtonStyle,
                  child: Text(isEdit ? 'ACTUALIZAR SOLICITUD' : 'GUARDAR SOLICITUD'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Solicitud'),
        content: const Text('¿Estás seguro de que deseas eliminar esta solicitud? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService().deleteSolicitud(id);
        _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _getUnidad(String? producto) {
    if (producto == null) return 'Kg';
    final prod = _productos.firstWhere(
      (p) => (p['codigo'] ?? p['producto']) == producto,
      orElse: () => ProductosData.masterCatalog.firstWhere(
        (p) => (p['codigo'] ?? p['producto']) == producto,
        orElse: () => {'unidad': 'Kg'},
      ),
    );
    final String u = prod['unidad'] ?? 'Kg';
    if (u.toLowerCase().contains('uni')) return 'Unidades';
    return u;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        
        if (isDesktop) {
          return Scaffold(
            backgroundColor: DesignTokens.surfaceLow,
            body: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: HoneycombPainter(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    GeoSidebar(userRole: _userRole ?? '', userEmail: _userEmail ?? '', displayName: _userEmail ?? ''),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
                        child: Column(
                          children: [
                            _buildHeader(isDesktop),
                            Expanded(
                              child: _loading 
                                ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                                : TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildList('Recolección', isDesktop),
                                      _buildList('Distribución', isDesktop),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: DesignTokens.surfaceLow,
          body: Column(
            children: [
              _buildHeader(isDesktop),
              Expanded(
                child: _loading 
                  ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList('Recolección', isDesktop),
                        _buildList('Distribución', isDesktop),
                      ],
                    ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addNecesidad,
            backgroundColor: DesignTokens.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('NUEVA SOLICITUD', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12, letterSpacing: 1)),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      color: isDesktop ? Colors.transparent : DesignTokens.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 16, isDesktop ? 40 : 16, isDesktop ? 0 : 16, 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: DesignTokens.primary),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Gestión de Solicitudes',
                    style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 24, color: DesignTokens.primary, letterSpacing: -0.5),
                  ),
                ),
                if (isDesktop) ...[
                  IconButton(
                    onPressed: () => setState(() => _isCardView = !_isCardView),
                    icon: Icon(_isCardView ? Icons.table_chart_rounded : Icons.dashboard_rounded, color: DesignTokens.primary, size: 22),
                    tooltip: 'Cambiar vista',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _generatePdf,
                    icon: const Icon(Icons.print_rounded, color: DesignTokens.primary, size: 22),
                    tooltip: 'Imprimir/Exportar',
                  ),
                  const SizedBox(width: 16),
                  _buildSearchBar(isDesktop),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _addNecesidad,
                    style: DesignTokens.primaryButtonStyle,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('NUEVA SOLICITUD'),
                  ),
                ],
              ],
            ),
          ),
          if (!isDesktop) Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSearchBar(isDesktop),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.black.withOpacity(0.05),
            indicatorColor: DesignTokens.secondary,
            indicatorWeight: 3,
            labelColor: DesignTokens.primary,
            unselectedLabelColor: Colors.black38,
            labelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'RECOLECCIONES'),
              Tab(text: 'DISTRIBUCIONES'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDesktop) {
    return Container(
      width: isDesktop ? 350 : double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar apicultor, localidad o producto...',
          hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black38),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildList(String tipo, bool isDesktop) {
    final list = _filteredNecesidades.where((n) => n['tipo'] == tipo).toList();
    
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text('No hay $tipo pendientes'.toLowerCase(), style: const TextStyle(color: Colors.black45)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: isDesktop 
        ? (_isCardView ? _buildKanbanView(list) : _buildTableView(list))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            itemCount: list.length,
            itemBuilder: (context, index) => _buildCard(list[index], isDesktop: false),
          ),
    );
  }

  Widget _buildKanbanView(List<Map<String, dynamic>> list) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildKanbanColumn('PENDIENTE', AppStates.pendiente, list)),
        const SizedBox(width: 16),
        Expanded(child: _buildKanbanColumn('ASIGNADA', AppStates.asignada, list)),
        const SizedBox(width: 16),
        Expanded(child: _buildKanbanColumn('EN CURSO', AppStates.enCurso, list)),
        const SizedBox(width: 16),
        Expanded(child: _buildKanbanColumn('TERMINADA', AppStates.terminado, list)),
      ],
    );
  }

  Widget _buildKanbanColumn(String title, String estado, List<Map<String, dynamic>> allList) {
    final filtered = allList.where((n) => AppStates.normalize(n['estado'] ?? AppStates.pendiente) == estado).toList();
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 1.5)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
                  child: Text('${filtered.length}', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black12),
                        SizedBox(height: 16),
                        Text('Vacío', style: TextStyle(fontFamily: 'Inter', color: Colors.black45, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCard(filtered[i], isDesktop: true),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(List<Map<String, dynamic>> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9F9F9)),
          dataRowMaxHeight: 64,
          dataRowMinHeight: 64,
          showBottomBorder: true,
          columns: const [
            DataColumn(label: Text('TIPO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('APICULTOR / LOC.', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('PRODUCTO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('CANTIDAD', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('ESTADO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
          ],
          rows: list.map((n) {
            final api = n['apicultores'] ?? {};
            final estado = AppStates.normalize(n['estado'] ?? AppStates.pendiente);
            return DataRow(
              cells: [
                DataCell(Text(n['tipo'].toString(), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(Text('${api['nombre'] ?? '-'} • ${api['localidad'] ?? '-'}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87))),
                DataCell(Text('${n['producto']}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black54))),
                DataCell(Text('${n['cantidad']} ${_getUnidad(n['producto'])}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87))),
                DataCell(_buildStatusBadge(estado)),
                DataCell(
                  estado == AppStates.pendiente
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 16, color: DesignTokens.primary), onPressed: () => _editNecesidad(n)),
                            IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent), onPressed: () => _confirmDelete(n['id'].toString())),
                          ],
                        )
                      : const SizedBox.shrink()
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(AppStates.stateBgColor(estado)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(AppStates.stateTextColor(estado)),
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final doc = pw.Document();

    final fontData = await PdfGoogleFonts.workSansRegular();
    final fontBold = await PdfGoogleFonts.workSansBold();

    final tipoActual = _tabController.index == 0 ? 'Recolección' : 'Distribución';
    final list = _filteredNecesidades.where((n) => n['tipo'] == tipoActual).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GeoLogística PWA - Gestión de Solicitudes', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey900)),
                  pw.Text(tipoActual.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.amber800)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: pw.TextStyle(font: fontData, fontSize: 10),
              headers: ['ID', 'Apicultor / Localidad', 'Producto', 'Cantidad', 'Estado'],
              data: list.map((n) {
                final api = n['apicultores'] ?? {};
                final estado = AppStates.normalize(n['estado'] ?? AppStates.pendiente);
                return [
                  n['id'].toString(),
                  '${api['nombre'] ?? '-'} • ${api['localidad'] ?? '-'}',
                  '${n['producto']}',
                  '${n['cantidad']} ${_getUnidad(n['producto'])}',
                  estado.toUpperCase(),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total de solicitudes: ${list.length}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              ]
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Resumen_Solicitudes_$tipoActual.pdf',
    );
  }

  Widget _buildCard(Map<String, dynamic> n, {bool isDesktop = false}) {
    final api = n['apicultores'] ?? {};
    final estado = n['estado'] ?? AppStates.pendiente;
    final normalizedEstado = AppStates.normalize(estado);
    final bool canNavigate = (normalizedEstado == AppStates.asignada || normalizedEstado == AppStates.enCurso);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: canNavigate
            ? () {
                final viajeId = _solicitudToViaje[n['id'].toString()];
                if (viajeId != null) {
                  context.push('/viajedetalle?viajeId=$viajeId');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo encontrar el viaje asociado a esta solicitud'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            : null,
        title: Text(
          '${n['producto']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Manrope', fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${api['nombre'] ?? 'Sin nombre'} • ${api['localidad'] ?? 'Sin loc.'}'),
            Text('${n['cantidad']} ${_getUnidad(n['producto'])} estimados', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF08201A))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (estado == AppStates.pendiente) ...[
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: DesignTokens.primary),
                onPressed: () => _editNecesidad(n),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () => _confirmDelete(n['id'].toString()),
              ),
            ],
            _buildStatusBadge(normalizedEstado),
            if (canNavigate) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: DesignTokens.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
