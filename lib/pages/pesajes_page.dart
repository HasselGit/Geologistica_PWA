import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';
import 'agregar_pesaje.dart';
import 'apicultor_detalle.dart';

/// Lista de pesajes agrupados por parada/viaje
class PesajesPageWidget extends StatefulWidget {
  const PesajesPageWidget({super.key});

  @override
  State<PesajesPageWidget> createState() => _PesajesPageWidgetState();
}

class _PesajesPageWidgetState extends State<PesajesPageWidget> {
  bool _loading = true;
  List<Map<String, dynamic>> _grupos = [];
  List<Map<String, dynamic>> _filteredGrupos = [];
  String _searchQuery = '';
  DateTime? _selectedDate;
  String? _userRole;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userEmail = email;
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      List<dynamic> rawPesajes = [];
      
      try {
        // Intento 1: Consulta con joins explícitos usando la sintaxis robusta de PostgREST
        final data = await client
            .from('pesajes')
            .select('*, paradas!parada_id(tipo, localidad, ubicacion, viajes!viaje_id(viaje_codigo, fecha))')
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 10));
        rawPesajes = List<dynamic>.from(data);
      } catch (joinErr) {
        print('PesajesPage: Error en consulta con joins: $joinErr. Ejecutando fallback directo...');
        // Fallback: consulta directa a pesajes y resoluciones manuales
        final data = await client
            .from('pesajes')
            .select('*')
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 10));
        
        final List<Map<String, dynamic>> pesajesDirectos = List<Map<String, dynamic>>.from(data);
        
        if (pesajesDirectos.isNotEmpty) {
          // Obtener todas las paradas involucradas
          final Set<String> paradaIds = pesajesDirectos
              .map((p) => p['parada_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
              
          Map<String, Map<String, dynamic>> paradasMap = {};
          if (paradaIds.isNotEmpty) {
            try {
              final paradasData = await client
                  .from('paradas')
                  .select('id, tipo, localidad, ubicacion, viaje_id')
                  .filter('id', 'in', paradaIds.toList());
              for (var p in (paradasData as List)) {
                paradasMap[p['id'].toString()] = Map<String, dynamic>.from(p);
              }
            } catch (paradasErr) {
              print('PesajesPage: Error en fallback paradas: $paradasErr');
            }
          }
          
          // Obtener todos los viajes involucrados
          final Set<String> viajeIds = paradasMap.values
              .map((p) => p['viaje_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
              
          Map<String, Map<String, dynamic>> viajesMap = {};
          if (viajeIds.isNotEmpty) {
            try {
              final viajesData = await client
                  .from('viajes')
                  .select('id, viaje_codigo, fecha')
                  .filter('id', 'in', viajeIds.toList());
              for (var v in (viajesData as List)) {
                viajesMap[v['id'].toString()] = Map<String, dynamic>.from(v);
              }
            } catch (viajesErr) {
              print('PesajesPage: Error en fallback viajes: $viajesErr');
            }
          }
          
          // Reconstruir la estructura esperada por el código
          for (var p in pesajesDirectos) {
            final pId = p['parada_id']?.toString();
            final parada = paradasMap[pId];
            if (parada != null) {
              final vId = parada['viaje_id']?.toString();
              final viaje = viajesMap[vId];
              if (viaje != null) {
                parada['viaje'] = viaje;
              }
              p['parada'] = parada;
            }
            rawPesajes.add(p);
          }
        }
      }

      final pesajes = List<Map<String, dynamic>>.from(rawPesajes);

      if (pesajes.isEmpty) {
        if (mounted) setState(() { _grupos = []; _filteredGrupos = []; _loading = false; });
        return;
      }

      // Agrupar por parada_id
      final Map<String, List<Map<String, dynamic>>> porParada = {};
      for (var p in pesajes) {
        final paradaId = p['parada_id']?.toString() ?? 'sin_parada';
        porParada.putIfAbsent(paradaId, () => []).add(p);
      }

      // Construir grupos enriquecidos
      final grupos = porParada.entries.map((entry) {
        final paradaId = entry.key;
        final items = entry.value;
        final firstItem = items[0];
        final parada = (firstItem['paradas'] as Map?) ?? (firstItem['parada'] as Map?) ?? {};
        final viaje = (parada['viajes'] as Map?) ?? (parada['viaje'] as Map?) ?? {};

        final totalBruto = items.fold(0.0, (s, p) => s + (double.tryParse(p['peso_bruto']?.toString() ?? '0') ?? 0));
        final totalTara = items.fold(0.0, (s, p) => s + (double.tryParse(p['tara']?.toString() ?? '0') ?? 0));
        
        final totalNetoCalc = items.fold(0.0, (s, p) {
          final netoDB = double.tryParse(p['peso_neto']?.toString() ?? '');
          if (netoDB != null) return s + netoDB;
          final b = double.tryParse(p['peso_bruto']?.toString() ?? '0') ?? 0;
          final t = double.tryParse(p['tara']?.toString() ?? '0') ?? 0;
          return s + (b - t);
        });

        final apicId = firstItem['apicultor_id']?.toString() ?? 'S/D';

        return {
          'parada_id': paradaId,
          'viaje_id': firstItem['viaje_id']?.toString() ?? '',
          'viaje_codigo': viaje['viaje_codigo'] ?? 'V-S/N',
          'viaje_fecha': viaje['fecha'],
          'apicultor_id': apicId,
          'apicultor': parada['ubicacion'] ?? parada['localidad'] ?? apicId,
          'localidad': parada['localidad'] ?? 'S/D',
          'tipo': parada['tipo'] ?? 'Recolección',
          'items': items.map((it) {
            if (it['peso_neto'] == null) {
               final b = double.tryParse(it['peso_bruto']?.toString() ?? '0') ?? 0;
               final t = double.tryParse(it['tara']?.toString() ?? '0') ?? 0;
               it['peso_neto'] = b - t;
            }
            return it;
          }).toList(),
          'tcm_count': items.length,
          'total_bruto': totalBruto,
          'total_tara': totalTara,
          'total_neto': totalNetoCalc,
          'fecha': firstItem['created_at'],
        };
      }).toList();

      // Ordenar por fecha descendente
      grupos.sort((a, b) {
        final fa = DateTime.tryParse(a['fecha']?.toString() ?? '') ?? DateTime(2000);
        final fb = DateTime.tryParse(b['fecha']?.toString() ?? '') ?? DateTime(2000);
        return fb.compareTo(fa);
      });

      if (mounted) {
        setState(() {
          _grupos = grupos;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('PesajesPage: Error: $e');
      if (mounted) {
         setState(() => _loading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredGrupos = _grupos.where((g) {
        final query = _searchQuery.toLowerCase();
        
        final apicultor = (g['apicultor'] ?? '').toString().toLowerCase();
        final localidad = (g['localidad'] ?? '').toString().toLowerCase();
        final viajeCode = (g['viaje_codigo'] ?? '').toString().toLowerCase();
        final fechaStr = g['viaje_fecha'] != null ? DateFormat('dd/MM/yy').format(DateTime.tryParse(g['viaje_fecha'].toString()) ?? DateTime.now()).toLowerCase() : '';
        
        final matchesSearch = apicultor.contains(query) ||
                              localidad.contains(query) ||
                              viajeCode.contains(query) ||
                              fechaStr.contains(query);
                              
        bool dateMatch = true;
        if (_selectedDate != null) {
          final dateVal = g['viaje_fecha'] ?? g['fecha'];
          final parsed = DateTime.tryParse(dateVal?.toString() ?? '');
          dateMatch = parsed != null &&
                      parsed.year == _selectedDate!.year &&
                      parsed.month == _selectedDate!.month &&
                      parsed.day == _selectedDate!.day;
        }
        return matchesSearch && dateMatch;
      }).toList();
    });
  }

  @override
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F3),
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: const Color(0xFFFBF9F8),
              child: Row(
                children: [
                  if (context.canPop()) ...[
                    GestureDetector(
                      onTap: () => context.pop(),
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
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: const Icon(Icons.home_rounded, size: 20, color: DesignTokens.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Registro de Pesajes',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Color(0xFF08201A),
                    ),
                  ),
                  const Spacer(),
                  // Search field
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Viaje, Apicultor o Fecha...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF5F3F3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFC2C8C4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFC2C8C4)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF08201A)),
                    onPressed: _fetchData,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFDBE49)),
                    )
                  : _filteredGrupos.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.scale_rounded, size: 56, color: Color(0x33424846)),
                              SizedBox(height: 16),
                              Text(
                                'Sin pesajes registrados',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF424846),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _filteredGrupos.length,
                            itemBuilder: (context, index) =>
                                _buildGrupoCard(_filteredGrupos[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrupoCard(Map<String, dynamic> grupo) {
    final viajeCodigo = grupo['viaje_codigo']?.toString() ?? 'S/V';
    final paradaLocalidad =
        grupo['localidad']?.toString() ?? grupo['apicultor']?.toString() ?? 'S/P';
    final List<dynamic> pesajes =
        (grupo['items'] as List?)?.cast<dynamic>() ?? [];
    final totalNeto = (grupo['total_neto'] as double?) ?? 0.0;
    final totalBruto = (grupo['total_bruto'] as double?) ?? 0.0;
    final fechaStr = grupo['viaje_fecha'] != null
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(grupo['viaje_fecha'].toString()) ?? DateTime.now())
        : '--/--/--';
    final viajeId = grupo['viaje_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0D08201A)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF08201A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alt_route_rounded,
                            size: 14, color: Color(0xFF08201A)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => context.push('/viajedetalle?viajeId=$viajeId'),
                          child: Text(
                            viajeCodigo,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: DesignTokens.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(fechaStr, style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.5))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4F0E1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pesajes.length} pesajes',
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Color(0xFF1A6B43),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      paradaLocalidad,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF424846)),
                    ),
                    if (pesajes.isNotEmpty) ...[
                      const Divider(height: 20),
                      ...pesajes.map((p) {
                        final item = p as Map<String, dynamic>;
                        final bruto =
                            (double.tryParse(item['peso_bruto']?.toString() ?? '0') ?? 0);
                        final tara =
                            (double.tryParse(item['tara']?.toString() ?? '0') ?? 0);
                        final neto = bruto - tara;
                        final senasa =
                            item['senasa_codigo']?.toString() ??
                            item['codigo_senasa']?.toString() ??
                            'S/C';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: Color(0xFFC68E17)),
                              const SizedBox(width: 8),
                              Text(
                                senasa,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  color: Color(0xFF424846),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Bruto: ${bruto.toStringAsFixed(1)}kg',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: Color(0xFF424846),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Neto: ${neto.toStringAsFixed(1)}kg',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: Color(0xFF08201A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL NETO: ',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Color(0xFF424846),
                            ),
                          ),
                          Text(
                            '${totalNeto.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFFC68E17),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> g) {
    final items = g['items'] as List<Map<String, dynamic>>;
    final viajeCode = g['viaje_codigo'] as String;
    final apicultor = g['apicultor'] as String;
    final localidad = g['localidad'] as String;
    final tcmCount = g['tcm_count'] as int;
    final totalNeto = g['total_neto'] as double;
    final totalBruto = g['total_bruto'] as double;
    final fechaStr = g['viaje_fecha'] != null
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(g['viaje_fecha'].toString()) ?? DateTime.now())
        : '--/--/--';

    return GestureDetector(
      onTap: () => _showDetalle(g),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: DesignTokens.primary.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.scale_rounded, size: 18, color: DesignTokens.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(viajeCode, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: DesignTokens.primary)),
                        Text(fechaStr, style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.4))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(20)),
                    child: Text('$tcmCount TCM', style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFC68E17))),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _infoChip(Icons.person_pin_circle_rounded, 'APICULTOR', apicultor)),
                      const SizedBox(width: 12),
                      Expanded(child: _infoChip(Icons.location_on_rounded, 'LOCALIDAD', localidad)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _miniStat('BRUTO', totalBruto > 0 ? '${totalBruto.toStringAsFixed(0)} kg' : '—'),
                      const SizedBox(width: 16),
                      _miniStat('NETO', totalNeto > 0 ? '${totalNeto.toStringAsFixed(0)} kg' : '—', highlight: true),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Text('VER DETALLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.6), fontFamily: 'Work Sans')),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 14, color: DesignTokens.primary.withOpacity(0.4)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: DesignTokens.primary.withOpacity(0.4)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black38)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF424846)), overflow: TextOverflow.ellipsis),
            ],
          )),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black38)),
        Text(value, style: TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w800, color: highlight ? DesignTokens.secondary : const Color(0xFF424846))),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.scale_outlined, size: 48, color: DesignTokens.secondary),
          ),
          const SizedBox(height: 24),
          Text('Sin registros de pesajes', style: DesignTokens.headlineStyle().copyWith(fontSize: 18, color: const Color(0xFF424846))),
          const SizedBox(height: 8),
          Text('Los pesajes aparecerán aquí cuando se registren\ndesde una parada de recolección activa.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black38)),
        ],
      ),
    );
  }

  // ─── MODAL DE DETALLE ─────────────────────────────────────────────────────────
  void _showDetalle(Map<String, dynamic> g) {
    final items = g['items'] as List<Map<String, dynamic>>;
    final apicultor = g['apicultor'] as String;
    final localidad = g['localidad'] as String;
    final viajeCode = g['viaje_codigo'] as String;
    final totalBruto = g['total_bruto'] as double;
    final totalTara = g['total_tara'] as double;
    final totalNeto = g['total_neto'] as double;
    final fechaStr = g['viaje_fecha'] != null
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(g['viaje_fecha'].toString()) ?? DateTime.now())
        : '--/--/--';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBFBFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(2))),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(viajeCode, style: DesignTokens.headlineStyle().copyWith(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('$apicultor  •  $localidad  •  $fechaStr', style: const TextStyle(fontSize: 13, color: Colors.black45)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(20)),
                      child: Text('${items.length} TCM', style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFC68E17))),
                    ),
                  ],
                ),
              ),
              // Totales
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(children: [
                  _totalBox('BRUTO TOTAL', totalBruto, false),
                  const SizedBox(width: 10),
                  _totalBox('TARA TOTAL', totalTara, false),
                  const SizedBox(width: 10),
                  _totalBox('NETO TOTAL', totalNeto, true),
                ]),
              ),
              // Tabla
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(color: Color(0xFF1E302C), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                        child: Row(children: [
                          _th('#', 1), _th('CÓD. SENASA', 4), _th('BRUTO', 2, right: true), _th('TARA', 2, right: true), _th('NETO', 2, right: true),
                        ]),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('Sin registros', style: TextStyle(color: Colors.black38)))
                            : ListView.builder(
                                controller: sc,
                                itemCount: items.length,
                                itemBuilder: (ctx, i) => _detalleRow(i + 1, items[i]),
                              ),
                      ),

                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalBox(String label, double value, bool highlight) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? DesignTokens.secondary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? DesignTokens.secondary.withOpacity(0.2) : const Color(0xFFEEEEEE)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: highlight ? DesignTokens.secondary : Colors.black38, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(0)} kg', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 16, color: highlight ? DesignTokens.secondary : const Color(0xFF424846))),
        ]),
      ),
    );
  }

  Widget _th(String text, int flex, {bool right = false}) {
    return Expanded(flex: flex, child: Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontFamily: 'Work Sans', color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)));
  }

  Widget _detalleRow(int index, Map<String, dynamic> item) {
    final bruto = double.tryParse(item['peso_bruto']?.toString() ?? '0') ?? 0;
    final tara = double.tryParse(item['tara']?.toString() ?? '0') ?? 0;
    final neto = double.tryParse(item['peso_neto']?.toString() ?? '0') ?? 0;
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(children: [
        Expanded(flex: 1, child: Text('$index', style: const TextStyle(fontSize: 11, color: Colors.black38))),
        Expanded(flex: 4, child: Text(item['senasa_codigo']?.toString() ?? 'TCM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF424846)), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text('${bruto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
        Expanded(flex: 2, child: Text('${tara.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
        Expanded(flex: 2, child: Text('${neto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w800, color: DesignTokens.secondary))),
      ]),
    );
  }

  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: DesignTokens.surfaceLow,
          body: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: const HoneycombPainter(),
                  ),
                ),
              ),
              isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeoSidebar(
            userRole: _userRole ?? '',
            userEmail: _userEmail ?? '',
            displayName: _userEmail ?? '',
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(120, 40, 40, 40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Filtros Laterales (Fijos)
                SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (context.canPop()) ...[
                            InkWell(
                              onTap: () => context.pop(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                                ),
                                child: const Tooltip(
                                  message: 'Atrás',
                                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: DesignTokens.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          InkWell(
                            onTap: () => context.go('/home'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black.withOpacity(0.05)),
                              ),
                              child: const Tooltip(
                                message: 'Volver al Inicio',
                                child: Icon(Icons.home_rounded, size: 20, color: DesignTokens.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Histórico de Pesajes',
                              style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF08201A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF08201A).withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BÚSQUEDA', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Viaje, Apicultor o Fecha...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFFBF9F8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              onChanged: (val) { setState(() { _searchQuery = val; _applyFilters(); }); },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // DataGrid Corporativo
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF08201A).withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Textura de Fondo Translucido (2%)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF08201A).withOpacity(0.02),
                                    const Color(0xFFC68E17).withOpacity(0.02),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          // Icono Vectorizado Absoluto (3%)
                          Positioned(
                            bottom: -20,
                            right: -20,
                            child: Icon(Icons.scale_rounded, size: 120, color: const Color(0xFF08201A).withOpacity(0.03)),
                          ),
                          // Tabla de Datos Densa
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFF08201A).withOpacity(0.05)))),
                                child: const Text(
                                  'REGISTROS AUDITADOS',
                                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2, color: Color(0xFF08201A)),
                                ),
                              ),
                              Expanded(
                                child: _loading 
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFC68E17)))
                                  : SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(const Color(0xFFFBF9F8)),
                                        dataRowMinHeight: 50,
                                        dataRowMaxHeight: 50,
                                        horizontalMargin: 20,
                                        columnSpacing: 20,
                                        columns: const [
                                          DataColumn(label: Text('VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('FECHA', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('APICULTOR / LOC', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('TCM', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('BRUTO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('NETO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                          DataColumn(label: Text('ACCIÓN', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 11))),
                                        ],
                                        rows: _filteredGrupos.map((g) {
                                          final viajeCode = g['viaje_codigo'] as String;
                                          final viajeId = g['viaje_id']?.toString() ?? '';
                                          final fechaStr = g['viaje_fecha'] != null ? DateFormat('dd/MM/yy').format(DateTime.tryParse(g['viaje_fecha'].toString()) ?? DateTime.now()) : '--/--/--';
                                          final apicultor = g['apicultor'] as String;
                                          final localidad = g['localidad'] as String;
                                          final tcmCount = g['tcm_count'] as int;
                                          final totalBruto = g['total_bruto'] as double;
                                          final totalNeto = g['total_neto'] as double;
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                InkWell(
                                                  onTap: () => context.push('/viajedetalle?viajeId=$viajeId'),
                                                  child: Text(viajeCode, style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, color: DesignTokens.primary, decoration: TextDecoration.underline)),
                                                ),
                                              ),
                                              DataCell(Text(fechaStr, style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.black54))),
                                              DataCell(InkWell(
                                                onTap: () {
                                                  Navigator.push(context, MaterialPageRoute(builder: (context) => ApicultorDetalleWidget(apicultor: {'id': g['apicultor_id'], 'nombre': apicultor, 'localidad': localidad})));
                                                },
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(apicultor, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.primary, decoration: TextDecoration.underline)),
                                                    Text(localidad, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: const Color(0xFF08201A).withOpacity(0.5))),
                                                  ],
                                                ),
                                              )),
                                              DataCell(Text('$tcmCount', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14))),
                                              DataCell(Text(totalBruto.toStringAsFixed(1), style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.black54))),
                                              DataCell(Text(totalNeto.toStringAsFixed(1), style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, color: Color(0xFFC68E17)))),
                                              DataCell(
                                                TextButton(
                                                  onPressed: () => _showDetalle(g),
                                                  child: const Text('VER', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, color: Color(0xFF08201A))),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
